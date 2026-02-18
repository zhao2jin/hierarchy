@isTest
private class HistoryReportControllerTest {

    // ─────────────────────────────── Test data ────────────────────────────────

    @TestSetup
    static void makeData() {
        Timeline_Child_Config__c cfg = new Timeline_Child_Config__c(
            Name                      = 'Test-Account-Contact',
            Parent_Object_API_Name__c = 'Account',
            Child_Object_API_Name__c  = 'Contact',
            Child_Object_Label__c     = 'Contacts',
            Relationship_Field__c     = 'AccountId',
            Icon_Name__c              = 'standard:contact',
            Is_Active__c              = true
        );
        insert cfg;

        Timeline_Child_Config__c cfg2 = new Timeline_Child_Config__c(
            Name                      = 'Test-Opportunity-Account',
            Parent_Object_API_Name__c = 'Account',
            Child_Object_API_Name__c  = 'Opportunity',
            Child_Object_Label__c     = 'Opportunities',
            Relationship_Field__c     = 'AccountId',
            Icon_Name__c              = 'standard:opportunity',
            Is_Active__c              = true
        );
        insert cfg2;
    }

    // ─────────────────────────── getConfiguredObjects ─────────────────────────

    @isTest
    static void testGetConfiguredObjects() {
        Test.startTest();
        List<HistoryReportController.ObjectOption> opts =
            HistoryReportController.getConfiguredObjects();
        Test.stopTest();

        System.assertEquals(3, opts.size(),
            'Should return 3 unique object options (Account, Contact, Opportunity)');
    }

    @isTest
    static void testGetConfiguredObjectsWhenEmpty() {
        delete [SELECT Id FROM Timeline_Child_Config__c];

        Test.startTest();
        List<HistoryReportController.ObjectOption> opts =
            HistoryReportController.getConfiguredObjects();
        Test.stopTest();

        System.assertEquals(0, opts.size(),
            'Should return empty list when no active configs exist');
    }

    @isTest
    static void testGetConfiguredObjectsAreSorted() {
        Test.startTest();
        List<HistoryReportController.ObjectOption> opts =
            HistoryReportController.getConfiguredObjects();
        Test.stopTest();

        for (Integer i = 0; i < opts.size() - 1; i++) {
            System.assert(
                opts[i].label <= opts[i + 1].label,
                'Options should be sorted alphabetically by label'
            );
        }
    }

    // ──────────────────────────── getHistoryReport ────────────────────────────

    @isTest
    static void testGetHistoryReportNullParams() {
        Test.startTest();
        HistoryReportController.HistoryReportResult result =
            HistoryReportController.getHistoryReport(null, null, null, null, null);
        Test.stopTest();

        System.assert(result != null,                  'Result should not be null');
        System.assertEquals(0, result.records.size(), 'Should return empty records for null params');
        System.assertEquals(false, result.hasMore,    'hasMore should be false for null params');
    }

    @isTest
    static void testGetHistoryReportEmptyObjects() {
        Test.startTest();
        HistoryReportController.HistoryReportResult result =
            HistoryReportController.getHistoryReport(
                new List<String>(), null, null, 50, 0);
        Test.stopTest();

        System.assertEquals(0, result.records.size(),
            'Should return empty records for empty object list');
    }

    @isTest
    static void testGetHistoryReportWithValidObjects() {
        Test.startTest();
        HistoryReportController.HistoryReportResult result =
            HistoryReportController.getHistoryReport(
                new List<String>{ 'Account', 'Contact' },
                '2020-01-01', '2030-12-31', 50, 0
            );
        Test.stopTest();

        System.assert(result != null,         'Result should not be null');
        System.assert(result.records != null, 'Records list should not be null');
    }

    @isTest
    static void testGetHistoryReportWithInvalidObject() {
        Test.startTest();
        HistoryReportController.HistoryReportResult result =
            HistoryReportController.getHistoryReport(
                new List<String>{ 'NonExistentObject__c' },
                null, null, 50, 0
            );
        Test.stopTest();

        System.assert(result != null, 'Result should not be null for invalid object');
        System.assertEquals(0, result.records.size(),
            'Should return 0 records when history object does not exist');
    }

    @isTest
    static void testGetHistoryReportWithDateFilters() {
        Test.startTest();
        HistoryReportController.HistoryReportResult result =
            HistoryReportController.getHistoryReport(
                new List<String>{ 'Account' },
                '2020-01-01', '2020-01-02', 50, 0
            );
        Test.stopTest();

        System.assert(result != null, 'Result should not be null with date filters');
    }

    @isTest
    static void testGetHistoryReportPagination() {
        Test.startTest();
        HistoryReportController.HistoryReportResult page1 =
            HistoryReportController.getHistoryReport(
                new List<String>{ 'Account' }, null, null, 50, 0);
        HistoryReportController.HistoryReportResult page2 =
            HistoryReportController.getHistoryReport(
                new List<String>{ 'Account' }, null, null, 50, 50);
        Test.stopTest();

        System.assert(page1 != null, 'First page result should not be null');
        System.assert(page2 != null, 'Second page result should not be null');
    }

    // ─────────────────────────── getHistoryReportCount ────────────────────────

    @isTest
    static void testGetHistoryReportCountNull() {
        Test.startTest();
        Integer count = HistoryReportController.getHistoryReportCount(null, null, null);
        Test.stopTest();

        System.assertEquals(0, count, 'Count should be 0 for null params');
    }

    @isTest
    static void testGetHistoryReportCountEmpty() {
        Test.startTest();
        Integer count = HistoryReportController.getHistoryReportCount(
            new List<String>(), null, null);
        Test.stopTest();

        System.assertEquals(0, count, 'Count should be 0 for empty object list');
    }

    @isTest
    static void testGetHistoryReportCountWithValidObjects() {
        Test.startTest();
        Integer count = HistoryReportController.getHistoryReportCount(
            new List<String>{ 'Account', 'Contact' },
            '2020-01-01', '2030-12-31'
        );
        Test.stopTest();

        System.assert(count >= 0, 'Count should be a non-negative integer');
    }

    @isTest
    static void testGetHistoryReportCountInvalidObject() {
        Test.startTest();
        Integer count = HistoryReportController.getHistoryReportCount(
            new List<String>{ 'NonExistentObject__c' }, null, null);
        Test.stopTest();

        System.assertEquals(0, count,
            'Count should be 0 when the history object does not exist');
    }

    // ────────────────────────── Inner class unit tests ────────────────────────

    @isTest
    static void testHistoryReportRowComparableNewerFirst() {
        HistoryReportController.HistoryReportRow older = new HistoryReportController.HistoryReportRow();
        older.changedDate = DateTime.newInstance(2024, 1, 1, 0, 0, 0);

        HistoryReportController.HistoryReportRow newer = new HistoryReportController.HistoryReportRow();
        newer.changedDate = DateTime.newInstance(2024, 6, 1, 0, 0, 0);

        System.assert(newer.compareTo(older) < 0,  'Newer row should sort before older row');
        System.assert(older.compareTo(newer) > 0,  'Older row should sort after newer row');
        System.assertEquals(0, newer.compareTo(newer), 'Same date should compare equal');
    }

    @isTest
    static void testHistoryReportRowComparableNullDates() {
        HistoryReportController.HistoryReportRow withDate = new HistoryReportController.HistoryReportRow();
        withDate.changedDate = DateTime.newInstance(2024, 1, 1, 0, 0, 0);

        HistoryReportController.HistoryReportRow noDate = new HistoryReportController.HistoryReportRow();

        System.assert(withDate.compareTo(noDate) < 0,
            'Row with date should sort before null-date row');
        System.assertEquals(0,
            noDate.compareTo(new HistoryReportController.HistoryReportRow()),
            'Two null-date rows should compare equal');
    }

    @isTest
    static void testObjectOptionComparable() {
        HistoryReportController.ObjectOption a = new HistoryReportController.ObjectOption();
        a.label = 'Account';

        HistoryReportController.ObjectOption c = new HistoryReportController.ObjectOption();
        c.label = 'Contact';

        System.assert(a.compareTo(c) < 0,  'Account should sort before Contact');
        System.assert(c.compareTo(a) > 0,  'Contact should sort after Account');
        System.assertEquals(0, a.compareTo(a), 'Same option should compare equal');
    }

    @isTest
    static void testObjectOptionComparableNullLabel() {
        HistoryReportController.ObjectOption nullLabel = new HistoryReportController.ObjectOption();
        HistoryReportController.ObjectOption hasLabel  = new HistoryReportController.ObjectOption();
        hasLabel.label = 'Account';

        System.assert(nullLabel.compareTo(hasLabel) > 0,
            'Null label should sort after labelled option');
        System.assertEquals(0,
            nullLabel.compareTo(new HistoryReportController.ObjectOption()),
            'Two null-label options should compare equal');
    }
}
