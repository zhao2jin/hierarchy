/**
 * @description Controller for the Timeline History Viewer component.
 * Fetches history records and configured child object records for display in a unified timeline.
 */
public with sharing class TimelineHistoryController {

    private static final String HISTORY_SUFFIX = 'History';
    private static final Integer DEFAULT_LIMIT = 50;

    /**
     * @description Get all timeline data for a record including history and configured child objects
     * @param recordId The ID of the parent record
     * @param objectApiName The API name of the parent object
     * @param limitCount Maximum number of records to return
     * @param offsetCount Number of records to skip (for pagination)
     * @return List<TimelineRecord> Sorted list of timeline records (most recent first)
     */
    @AuraEnabled(cacheable=true)
    public static List<TimelineRecord> getTimelineData(
        String recordId,
        String objectApiName,
        Integer limitCount,
        Integer offsetCount
    ) {
        List<TimelineRecord> allRecords = new List<TimelineRecord>();

        if (String.isBlank(recordId) || String.isBlank(objectApiName)) {
            return allRecords;
        }

        Integer queryLimit = limitCount != null ? limitCount : DEFAULT_LIMIT;
        Integer queryOffset = offsetCount != null ? offsetCount : 0;

        // Get history records for the parent object
        allRecords.addAll(getHistoryRecords(recordId, objectApiName));

        // Get configured child object records
        allRecords.addAll(getChildObjectRecords(recordId, objectApiName));

        // Sort all records by date (most recent first)
        allRecords.sort();

        // Apply pagination
        List<TimelineRecord> paginatedRecords = new List<TimelineRecord>();
        Integer endIndex = Math.min(queryOffset + queryLimit, allRecords.size());
        for (Integer i = queryOffset; i < endIndex; i++) {
            paginatedRecords.add(allRecords[i]);
        }

        return paginatedRecords;
    }

    /**
     * @description Get the total count of timeline records for pagination
     * @param recordId The ID of the parent record
     * @param objectApiName The API name of the parent object
     * @return Integer Total count of all timeline records
     */
    @AuraEnabled(cacheable=true)
    public static Integer getTimelineRecordCount(String recordId, String objectApiName) {
        Integer totalCount = 0;

        if (String.isBlank(recordId) || String.isBlank(objectApiName)) {
            return totalCount;
        }

        // Count history records
        totalCount += getHistoryRecordCount(recordId, objectApiName);

        // Count child object records
        totalCount += getChildObjectRecordCount(recordId, objectApiName);

        return totalCount;
    }

    /**
     * @description Check if current user has permission to modify timeline configuration
     * @return Boolean True if user has the Modify_Timeline_Config custom permission
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasConfigPermission() {
        return FeatureManagement.checkPermission('Modify_Timeline_Config');
    }

    /**
     * @description Get unique object types present in the timeline for filtering
     * @param recordId The ID of the parent record
     * @param objectApiName The API name of the parent object
     * @return List<Map<String, String>> List of object types with their labels and icons
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableObjectTypes(String recordId, String objectApiName) {
        List<Map<String, String>> objectTypes = new List<Map<String, String>>();

        // Add history object
        String historyObjectName = getHistoryObjectName(objectApiName);
        if (isHistoryTrackingEnabled(objectApiName)) {
            Map<String, String> historyType = new Map<String, String>();
            historyType.put('value', historyObjectName);
            historyType.put('label', 'Field History');
            historyType.put('iconName', 'utility:history');
            objectTypes.add(historyType);
        }

        // Add configured child object histories
        List<Timeline_Child_Config__c> configs = getActiveConfigurations(objectApiName);
        for (Timeline_Child_Config__c config : configs) {
            String childHistoryObjectName = getHistoryObjectName(config.Child_Object_API_Name__c);
            // Only add if history tracking is enabled for this child object
            Schema.SObjectType historyType = Schema.getGlobalDescribe().get(childHistoryObjectName);
            if (historyType != null) {
                Map<String, String> childType = new Map<String, String>();
                childType.put('value', childHistoryObjectName);
                String label = String.isNotBlank(config.Child_Object_Label__c)
                    ? config.Child_Object_Label__c
                    : getObjectLabel(config.Child_Object_API_Name__c);
                childType.put('label', label + ' History');
                childType.put('iconName', String.isNotBlank(config.Icon_Name__c)
                    ? config.Icon_Name__c
                    : 'utility:history');
                objectTypes.add(childType);
            }
        }

        return objectTypes;
    }

    /**
     * @description Get history records for the parent object
     */
    private static List<TimelineRecord> getHistoryRecords(String recordId, String objectApiName) {
        List<TimelineRecord> historyRecords = new List<TimelineRecord>();

        String historyObjectName = getHistoryObjectName(objectApiName);

        // Check if history tracking is enabled for this object
        if (!isHistoryTrackingEnabled(objectApiName)) {
            return historyRecords;
        }

        try {
            String parentFieldName = getHistoryParentField(objectApiName);
            String query = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedById, CreatedBy.Name ' +
                          'FROM ' + String.escapeSingleQuotes(historyObjectName) + ' ' +
                          'WHERE ' + String.escapeSingleQuotes(parentFieldName) + ' = :recordId ' +
                          'ORDER BY CreatedDate DESC ' +
                          'LIMIT 1000';

            List<SObject> historyList = Database.query(query);

            for (SObject history : historyList) {
                TimelineRecord record = new TimelineRecord();
                record.id = (String) history.get('Id');
                record.objectApiName = historyObjectName;
                record.objectLabel = 'Field History';
                record.iconName = 'utility:history';
                record.dateValue = (Datetime) history.get('CreatedDate');
                record.formatDate();
                record.recordType = 'history';

                // Build title and description from field change
                String fieldName = (String) history.get('Field');
                Object oldValue = history.get('OldValue');
                Object newValue = history.get('NewValue');
                String createdByName = '';

                try {
                    SObject createdBy = history.getSObject('CreatedBy');
                    if (createdBy != null) {
                        createdByName = (String) createdBy.get('Name');
                    }
                } catch (Exception e) {
                    createdByName = 'Unknown User';
                }

                record.title = getFieldLabel(objectApiName, fieldName) + ' changed';
                record.description = buildHistoryDescription(oldValue, newValue, createdByName);

                record.additionalFields.put('fieldName', fieldName);
                record.additionalFields.put('oldValue', oldValue);
                record.additionalFields.put('newValue', newValue);
                record.additionalFields.put('createdByName', createdByName);

                historyRecords.add(record);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching history records: ' + e.getMessage());
        }

        return historyRecords;
    }

    /**
     * @description Get child object HISTORY records based on custom metadata configuration
     * Queries the history tracking of child objects related to the parent record
     */
    private static List<TimelineRecord> getChildObjectRecords(String recordId, String objectApiName) {
        List<TimelineRecord> childHistoryRecords = new List<TimelineRecord>();

        List<Timeline_Child_Config__c> configs = getActiveConfigurations(objectApiName);

        for (Timeline_Child_Config__c config : configs) {
            try {
                childHistoryRecords.addAll(queryChildObjectHistory(recordId, config));
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error fetching child history for ' +
                    config.Child_Object_API_Name__c + ': ' + e.getMessage());
            }
        }

        return childHistoryRecords;
    }

    /**
     * @description Query the history tracking of a child object
     * First gets child record IDs, then queries their history
     */
    private static List<TimelineRecord> queryChildObjectHistory(String recordId, Timeline_Child_Config__c config) {
        List<TimelineRecord> records = new List<TimelineRecord>();

        String childObject = config.Child_Object_API_Name__c;
        String relationshipField = config.Relationship_Field__c;
        String childHistoryObjectName = getHistoryObjectName(childObject);

        // Check if history tracking is enabled for this child object
        Schema.SObjectType historyType = Schema.getGlobalDescribe().get(childHistoryObjectName);
        if (historyType == null) {
            System.debug(LoggingLevel.INFO, 'History tracking not enabled for ' + childObject);
            return records;
        }

        // First, get all child record IDs related to the parent
        String childIdQuery = 'SELECT Id FROM ' + String.escapeSingleQuotes(childObject) + ' ' +
                              'WHERE ' + String.escapeSingleQuotes(relationshipField) + ' = :recordId';
        List<SObject> childRecords = Database.query(childIdQuery);

        if (childRecords.isEmpty()) {
            return records;
        }

        // Collect child record IDs
        Set<Id> childRecordIds = new Set<Id>();
        for (SObject child : childRecords) {
            childRecordIds.add((Id) child.get('Id'));
        }

        // Query history for these child records
        String parentFieldName = getChildHistoryParentField(childObject);
        String historyQuery = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedById, CreatedBy.Name, ' +
                              parentFieldName + ' ' +
                              'FROM ' + String.escapeSingleQuotes(childHistoryObjectName) + ' ' +
                              'WHERE ' + String.escapeSingleQuotes(parentFieldName) + ' IN :childRecordIds ' +
                              'ORDER BY CreatedDate DESC ' +
                              'LIMIT 500';

        List<SObject> historyList = Database.query(historyQuery);

        String objectLabel = String.isNotBlank(config.Child_Object_Label__c)
            ? config.Child_Object_Label__c
            : getObjectLabel(childObject);
        String iconName = String.isNotBlank(config.Icon_Name__c)
            ? config.Icon_Name__c
            : 'utility:history';

        for (SObject history : historyList) {
            TimelineRecord record = new TimelineRecord();
            record.id = (String) history.get('Id');
            record.objectApiName = childHistoryObjectName;
            record.objectLabel = objectLabel + ' History';
            record.iconName = iconName;
            record.dateValue = (Datetime) history.get('CreatedDate');
            record.formatDate();
            record.recordType = 'childHistory';

            // Get the parent record ID for linking
            Id parentRecordId = (Id) history.get(parentFieldName);
            record.recordUrl = '/' + parentRecordId;

            // Build title and description from field change
            String fieldName = (String) history.get('Field');
            Object oldValue = history.get('OldValue');
            Object newValue = history.get('NewValue');
            String createdByName = '';

            try {
                SObject createdBy = history.getSObject('CreatedBy');
                if (createdBy != null) {
                    createdByName = (String) createdBy.get('Name');
                }
            } catch (Exception e) {
                createdByName = 'Unknown User';
            }

            // Get field label for the child object
            record.title = objectLabel + ': ' + getFieldLabel(childObject, fieldName) + ' changed';
            record.description = buildHistoryDescription(oldValue, newValue, createdByName);

            record.additionalFields.put('fieldName', fieldName);
            record.additionalFields.put('oldValue', oldValue);
            record.additionalFields.put('newValue', newValue);
            record.additionalFields.put('createdByName', createdByName);
            record.additionalFields.put('childRecordId', parentRecordId);

            records.add(record);
        }

        return records;
    }

    /**
     * @description Get the parent field name for a child object's history object
     * Standard objects: {ObjectName}Id (e.g., OpportunityLineItemId)
     * Custom objects: ParentId
     */
    private static String getChildHistoryParentField(String childObjectApiName) {
        if (childObjectApiName.endsWith('__c')) {
            return 'ParentId';
        }
        return childObjectApiName + 'Id';
    }

    /**
     * @description Get count of history records
     */
    private static Integer getHistoryRecordCount(String recordId, String objectApiName) {
        String historyObjectName = getHistoryObjectName(objectApiName);

        if (!isHistoryTrackingEnabled(objectApiName)) {
            return 0;
        }

        try {
            String parentFieldName = getHistoryParentField(objectApiName);
            String query = 'SELECT COUNT() FROM ' + String.escapeSingleQuotes(historyObjectName) + ' ' +
                          'WHERE ' + String.escapeSingleQuotes(parentFieldName) + ' = :recordId';
            return Database.countQuery(query);
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * @description Get count of child object HISTORY records
     */
    private static Integer getChildObjectRecordCount(String recordId, String objectApiName) {
        Integer totalCount = 0;
        List<Timeline_Child_Config__c> configs = getActiveConfigurations(objectApiName);

        for (Timeline_Child_Config__c config : configs) {
            try {
                String childObject = config.Child_Object_API_Name__c;
                String relationshipField = config.Relationship_Field__c;
                String childHistoryObjectName = getHistoryObjectName(childObject);

                // Check if history tracking is enabled
                Schema.SObjectType historyType = Schema.getGlobalDescribe().get(childHistoryObjectName);
                if (historyType == null) {
                    continue;
                }

                // Get child record IDs
                String childIdQuery = 'SELECT Id FROM ' + String.escapeSingleQuotes(childObject) + ' ' +
                                      'WHERE ' + String.escapeSingleQuotes(relationshipField) + ' = :recordId';
                List<SObject> childRecords = Database.query(childIdQuery);

                if (childRecords.isEmpty()) {
                    continue;
                }

                Set<Id> childRecordIds = new Set<Id>();
                for (SObject child : childRecords) {
                    childRecordIds.add((Id) child.get('Id'));
                }

                // Count history records
                String parentFieldName = getChildHistoryParentField(childObject);
                String countQuery = 'SELECT COUNT() FROM ' + String.escapeSingleQuotes(childHistoryObjectName) + ' ' +
                                    'WHERE ' + String.escapeSingleQuotes(parentFieldName) + ' IN :childRecordIds';
                totalCount += Database.countQuery(countQuery);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error counting child history: ' + e.getMessage());
            }
        }

        return totalCount;
    }

    /**
     * @description Get active configurations for a parent object
     */
    private static List<Timeline_Child_Config__c> getActiveConfigurations(String objectApiName) {
        return [
            SELECT Id, Name, Child_Object_API_Name__c, Child_Object_Label__c,
                   Relationship_Field__c, Icon_Name__c, Is_Active__c
            FROM Timeline_Child_Config__c
            WHERE Parent_Object_API_Name__c = :objectApiName
            AND Is_Active__c = true
        ];
    }

    /**
     * @description Check if history tracking is enabled for an object
     */
    private static Boolean isHistoryTrackingEnabled(String objectApiName) {
        try {
            String historyObjectName = getHistoryObjectName(objectApiName);
            Schema.SObjectType historyType = Schema.getGlobalDescribe().get(historyObjectName);
            return historyType != null;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * @description Get the history object name for a given object
     * Standard objects: AccountHistory, OpportunityHistory
     * Custom objects: MyObject__History (not MyObject__cHistory)
     */
    private static String getHistoryObjectName(String objectApiName) {
        if (objectApiName.endsWith('__c')) {
            // Custom object: replace __c with __History
            return objectApiName.removeEnd('__c') + '__History';
        }
        // Standard object: append History
        return objectApiName + HISTORY_SUFFIX;
    }

    /**
     * @description Get the parent field name for a history object
     */
    private static String getHistoryParentField(String objectApiName) {
        // Standard objects use ObjectNameId, custom objects use ParentId
        if (objectApiName.endsWith('__c')) {
            return 'ParentId';
        }
        return objectApiName + 'Id';
    }

    /**
     * @description Check if a field exists on an object
     */
    private static Boolean fieldExists(String objectApiName, String fieldApiName) {
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType == null) {
                return false;
            }
            Map<String, Schema.SObjectField> fields = objectType.getDescribe().fields.getMap();
            return fields.containsKey(fieldApiName.toLowerCase());
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * @description Get the label for a field
     */
    private static String getFieldLabel(String objectApiName, String fieldApiName) {
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType == null) {
                return fieldApiName;
            }
            Map<String, Schema.SObjectField> fields = objectType.getDescribe().fields.getMap();
            Schema.SObjectField field = fields.get(fieldApiName.toLowerCase());
            if (field != null) {
                return field.getDescribe().getLabel();
            }
        } catch (Exception e) {
            // Fall through to return field API name
        }
        return fieldApiName;
    }

    /**
     * @description Get the label for an object
     */
    private static String getObjectLabel(String objectApiName) {
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType != null) {
                return objectType.getDescribe().getLabel();
            }
        } catch (Exception e) {
            // Fall through
        }
        return objectApiName;
    }

    /**
     * @description Build a description string for history changes
     */
    private static String buildHistoryDescription(Object oldValue, Object newValue, String createdByName) {
        String description = '';

        if (oldValue != null && newValue != null) {
            description = 'Changed from "' + String.valueOf(oldValue) + '" to "' + String.valueOf(newValue) + '"';
        } else if (oldValue != null) {
            description = 'Removed "' + String.valueOf(oldValue) + '"';
        } else if (newValue != null) {
            description = 'Set to "' + String.valueOf(newValue) + '"';
        }

        if (String.isNotBlank(createdByName)) {
            description += ' by ' + createdByName;
        }

        return description;
    }
}
