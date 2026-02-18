public with sharing class HistoryReportController {
    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PER_OBJECT_ROWS = 2000;

    // ─────────────────────────────── Public API ───────────────────────────────

    /**
     * Returns all unique objects (parent + child) from active Timeline_Child_Config__c
     * records so the report tab can offer an object picker.
     */
    @AuraEnabled(cacheable=true)
    public static List<ObjectOption> getConfiguredObjects() {
        try {
            Map<String, ObjectOption> optionMap = new Map<String, ObjectOption>();

            for (Timeline_Child_Config__c cfg : [
                SELECT Parent_Object_API_Name__c,
                       Child_Object_API_Name__c,
                       Child_Object_Label__c,
                       Icon_Name__c
                FROM   Timeline_Child_Config__c
                WHERE  Is_Active__c = true
                ORDER BY Child_Object_Label__c
            ]) {
                // Child object
                String childApi = cfg.Child_Object_API_Name__c;
                if (String.isNotBlank(childApi) && !optionMap.containsKey(childApi)) {
                    ObjectOption opt = new ObjectOption();
                    opt.label    = String.isNotBlank(cfg.Child_Object_Label__c)
                                    ? cfg.Child_Object_Label__c
                                    : resolveObjectLabel(childApi);
                    opt.value    = childApi;
                    opt.iconName = String.isNotBlank(cfg.Icon_Name__c)
                                    ? cfg.Icon_Name__c
                                    : 'standard:default';
                    optionMap.put(childApi, opt);
                }

                // Parent object
                String parentApi = cfg.Parent_Object_API_Name__c;
                if (String.isNotBlank(parentApi) && !optionMap.containsKey(parentApi)) {
                    ObjectOption opt = new ObjectOption();
                    opt.label    = resolveObjectLabel(parentApi);
                    opt.value    = parentApi;
                    opt.iconName = 'standard:default';
                    optionMap.put(parentApi, opt);
                }
            }

            List<ObjectOption> options = optionMap.values();
            options.sort();
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error retrieving configured objects: ' + e.getMessage());
        }
    }

    /**
     * Returns a page of history rows across the selected objects, optionally
     * filtered by date range.
     *
     * @param selectedObjectApiNames  Objects whose history to query
     * @param startDateStr            Inclusive start date (YYYY-MM-DD), or blank for no lower bound
     * @param endDateStr              Inclusive end date  (YYYY-MM-DD), or blank for no upper bound
     * @param limitCount              Page size (defaults to 50)
     * @param offsetCount             Zero-based starting row (for Load More)
     */
    @AuraEnabled
    public static HistoryReportResult getHistoryReport(
        List<String> selectedObjectApiNames,
        String startDateStr,
        String endDateStr,
        Integer limitCount,
        Integer offsetCount
    ) {
        try {
            if (selectedObjectApiNames == null || selectedObjectApiNames.isEmpty()) {
                return new HistoryReportResult();
            }

            Integer lim            = (limitCount  != null && limitCount  > 0)  ? limitCount  : DEFAULT_PAGE_SIZE;
            Integer off            = (offsetCount != null && offsetCount >= 0) ? offsetCount : 0;
            Integer perObjectLimit = Math.min(off + lim + 1, MAX_PER_OBJECT_ROWS);

            DateTime startDt = parseDate(startDateStr, true);
            DateTime endDt   = parseDate(endDateStr,   false);

            List<HistoryReportRow> allRows = new List<HistoryReportRow>();
            for (String objectApiName : selectedObjectApiNames) {
                allRows.addAll(queryObjectHistory(objectApiName, startDt, endDt, perObjectLimit));
            }
            allRows.sort();

            HistoryReportResult result = new HistoryReportResult();
            Integer startIdx = Math.min(off, allRows.size());
            Integer endIdx   = Math.min(off + lim, allRows.size());
            List<HistoryReportRow> page = new List<HistoryReportRow>();
            for (Integer i = startIdx; i < endIdx; i++) {
                page.add(allRows[i]);
            }
            result.records = page;
            result.hasMore = allRows.size() > (off + lim);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error retrieving history report: ' + e.getMessage());
        }
    }

    /**
     * Returns the total number of history records matching the filters.
     * Runs COUNT() per object – does not consume row-count governor limits.
     */
    @AuraEnabled
    public static Integer getHistoryReportCount(
        List<String> selectedObjectApiNames,
        String startDateStr,
        String endDateStr
    ) {
        try {
            if (selectedObjectApiNames == null || selectedObjectApiNames.isEmpty()) {
                return 0;
            }

            DateTime startDt = parseDate(startDateStr, true);
            DateTime endDt   = parseDate(endDateStr,   false);
            Integer  total   = 0;

            for (String objectApiName : selectedObjectApiNames) {
                String histObj = resolveHistoryObjectName(objectApiName);
                if (histObj == null) continue;
                try {
                    String q = 'SELECT COUNT() FROM ' + histObj;
                    List<String> clauses = buildWhereClauses(startDt, endDt);
                    if (!clauses.isEmpty()) {
                        q += ' WHERE ' + String.join(clauses, ' AND ');
                    }
                    total += Database.countQuery(q);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN,
                        'Count failed for ' + objectApiName + ': ' + ex.getMessage());
                }
            }
            return total;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error counting history records: ' + e.getMessage());
        }
    }

    // ─────────────────────────────── Private helpers ──────────────────────────

    private static List<HistoryReportRow> queryObjectHistory(
        String   objectApiName,
        DateTime startDt,
        DateTime endDt,
        Integer  perObjectLimit
    ) {
        List<HistoryReportRow> rows = new List<HistoryReportRow>();
        try {
            String histObj = resolveHistoryObjectName(objectApiName);
            if (histObj == null) return rows;

            String parentIdField     = resolveParentIdField(objectApiName);
            String relationshipName  = parentIdField.removeEnd('Id');
            String objectLabel       = resolveObjectLabel(objectApiName);

            List<String> clauses = buildWhereClauses(startDt, endDt);
            String q =
                'SELECT Id, ' + parentIdField + ', ' + relationshipName + '.Name' +
                ', Field, OldValue, NewValue, CreatedBy.Name, CreatedDate' +
                ' FROM ' + histObj;
            if (!clauses.isEmpty()) {
                q += ' WHERE ' + String.join(clauses, ' AND ');
            }
            q += ' ORDER BY CreatedDate DESC LIMIT ' + perObjectLimit;

            for (SObject rec : Database.query(q)) {
                HistoryReportRow row = new HistoryReportRow();
                row.id            = (String)   rec.get('Id');
                row.objectApiName = objectApiName;
                row.objectLabel   = objectLabel;
                row.recordId      = (String)   rec.get(parentIdField);

                try {
                    SObject parent = rec.getSObject(relationshipName);
                    row.recordName = parent != null ? (String) parent.get('Name') : row.recordId;
                } catch (Exception ex) {
                    row.recordName = row.recordId;
                }

                row.recordUrl   = '/lightning/r/' + objectApiName + '/' + row.recordId + '/view';

                String fieldApiName = (String) rec.get('Field');
                row.fieldChanged = resolveFieldLabel(objectApiName, fieldApiName);

                Object oldVal  = rec.get('OldValue');
                Object newVal  = rec.get('NewValue');
                row.oldValue   = oldVal != null ? String.valueOf(oldVal) : '';
                row.newValue   = newVal != null ? String.valueOf(newVal) : '';

                SObject createdBy = rec.getSObject('CreatedBy');
                row.changedBy  = createdBy != null ? (String) createdBy.get('Name') : '';

                row.changedDate          = (DateTime) rec.get('CreatedDate');
                row.changedDateFormatted = row.changedDate != null
                    ? row.changedDate.format('MMM d, yyyy \'at\' h:mm a')
                    : '';

                rows.add(row);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'History query failed for ' + objectApiName + ': ' + e.getMessage());
        }
        return rows;
    }

    private static List<String> buildWhereClauses(DateTime startDt, DateTime endDt) {
        List<String> clauses = new List<String>();
        if (startDt != null) {
            clauses.add('CreatedDate >= ' + startDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        }
        if (endDt != null) {
            clauses.add('CreatedDate <= ' + endDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        }
        return clauses;
    }

    private static DateTime parseDate(String dateStr, Boolean isStart) {
        if (String.isBlank(dateStr)) return null;
        try {
            Date d = Date.valueOf(dateStr);
            return isStart
                ? DateTime.newInstance(d, Time.newInstance(0,  0,  0,  0))
                : DateTime.newInstance(d, Time.newInstance(23, 59, 59, 999));
        } catch (Exception e) {
            return null;
        }
    }

    /** Converts 'Account' → 'AccountHistory', 'My_Obj__c' → 'My_Obj__History'.
     *  Returns null when the history object does not exist in the org schema. */
    private static String resolveHistoryObjectName(String objectApiName) {
        if (String.isBlank(objectApiName)) return null;
        String histName = objectApiName.endsWith('__c')
            ? objectApiName.replace('__c', '__History')
            : objectApiName + 'History';
        return Schema.getGlobalDescribe().containsKey(histName.toLowerCase())
            ? histName
            : null;
    }

    /** 'Account' → 'AccountId',  custom objects → 'ParentId' */
    private static String resolveParentIdField(String objectApiName) {
        return objectApiName.endsWith('__c') ? 'ParentId' : objectApiName + 'Id';
    }

    private static String resolveObjectLabel(String objectApiName) {
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
            return sot != null ? sot.getDescribe().getLabel() : objectApiName;
        } catch (Exception e) {
            return objectApiName;
        }
    }

    private static String resolveFieldLabel(String objectApiName, String fieldName) {
        if (String.isBlank(fieldName)) return '';
        if (fieldName == 'created') return 'Record Created';
        if (fieldName == 'deleted') return 'Record Deleted';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
            if (sot == null) return fieldName;
            Schema.SObjectField fld =
                sot.getDescribe().fields.getMap().get(fieldName.toLowerCase());
            return fld != null ? fld.getDescribe().getLabel() : fieldName;
        } catch (Exception e) {
            return fieldName;
        }
    }

    // ─────────────────────────────── Inner classes ────────────────────────────

    public class ObjectOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String iconName;

        public Integer compareTo(Object other) {
            ObjectOption o = (ObjectOption) other;
            if (label == null && o.label == null) return 0;
            if (label == null) return 1;
            if (o.label == null) return -1;
            return label.compareTo(o.label);
        }
    }

    public class HistoryReportResult {
        @AuraEnabled public List<HistoryReportRow> records = new List<HistoryReportRow>();
        @AuraEnabled public Boolean hasMore = false;
    }

    public class HistoryReportRow implements Comparable {
        @AuraEnabled public String   id;
        @AuraEnabled public String   objectApiName;
        @AuraEnabled public String   objectLabel;
        @AuraEnabled public String   recordId;
        @AuraEnabled public String   recordName;
        @AuraEnabled public String   recordUrl;
        @AuraEnabled public String   fieldChanged;
        @AuraEnabled public String   oldValue;
        @AuraEnabled public String   newValue;
        @AuraEnabled public String   changedBy;
        @AuraEnabled public DateTime changedDate;
        @AuraEnabled public String   changedDateFormatted;

        /** Sorts newest-first. Null dates sort to the end. */
        public Integer compareTo(Object other) {
            HistoryReportRow o = (HistoryReportRow) other;
            if (changedDate == null && o.changedDate == null) return 0;
            if (changedDate == null) return 1;
            if (o.changedDate == null) return -1;
            if (changedDate > o.changedDate) return -1;
            if (changedDate < o.changedDate) return 1;
            return 0;
        }
    }
}
