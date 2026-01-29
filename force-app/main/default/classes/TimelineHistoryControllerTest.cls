/**
 * @description Test class for TimelineHistoryController
 */
@isTest
private class TimelineHistoryControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create test Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;

        // Create related Tasks
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 5; i++) {
            tasks.add(new Task(
                Subject = 'Test Task ' + i,
                WhatId = testOpp.Id,
                Status = 'Not Started',
                Priority = 'Normal'
            ));
        }
        insert tasks;

        // Create related Events
        List<Event> events = new List<Event>();
        for (Integer i = 0; i < 3; i++) {
            events.add(new Event(
                Subject = 'Test Event ' + i,
                WhatId = testOpp.Id,
                StartDateTime = DateTime.now().addDays(i),
                EndDateTime = DateTime.now().addDays(i).addHours(1)
            ));
        }
        insert events;
    }

    @isTest
    static void testGetTimelineData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<TimelineRecord> records = TimelineHistoryController.getTimelineData(
            opp.Id,
            'Opportunity',
            50,
            0
        );
        Test.stopTest();

        // Should return history records (if enabled) - actual count depends on org setup
        System.assertNotEquals(null, records, 'Records list should not be null');
    }

    @isTest
    static void testGetTimelineDataWithNullParams() {
        Test.startTest();
        List<TimelineRecord> records = TimelineHistoryController.getTimelineData(
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(0, records.size(), 'Should return empty list for null params');
    }

    @isTest
    static void testGetTimelineDataWithBlankParams() {
        Test.startTest();
        List<TimelineRecord> records = TimelineHistoryController.getTimelineData(
            '',
            '',
            50,
            0
        );
        Test.stopTest();

        System.assertEquals(0, records.size(), 'Should return empty list for blank params');
    }

    @isTest
    static void testGetTimelineRecordCount() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        Integer count = TimelineHistoryController.getTimelineRecordCount(
            opp.Id,
            'Opportunity'
        );
        Test.stopTest();

        System.assertNotEquals(null, count, 'Count should not be null');
    }

    @isTest
    static void testGetTimelineRecordCountWithNullParams() {
        Test.startTest();
        Integer count = TimelineHistoryController.getTimelineRecordCount(null, null);
        Test.stopTest();

        System.assertEquals(0, count, 'Should return 0 for null params');
    }

    @isTest
    static void testHasConfigPermission() {
        Test.startTest();
        Boolean hasPermission = TimelineHistoryController.hasConfigPermission();
        Test.stopTest();

        // Default should be false unless permission is assigned
        System.assertNotEquals(null, hasPermission, 'Permission check should return a value');
    }

    @isTest
    static void testGetAvailableObjectTypes() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<Map<String, String>> objectTypes = TimelineHistoryController.getAvailableObjectTypes(
            opp.Id,
            'Opportunity'
        );
        Test.stopTest();

        System.assertNotEquals(null, objectTypes, 'Object types list should not be null');
    }

    @isTest
    static void testTimelineRecordComparable() {
        TimelineRecord record1 = new TimelineRecord();
        record1.dateValue = DateTime.now();

        TimelineRecord record2 = new TimelineRecord();
        record2.dateValue = DateTime.now().addDays(-1);

        TimelineRecord record3 = new TimelineRecord();
        record3.dateValue = null;

        TimelineRecord record4 = new TimelineRecord();
        record4.dateValue = null;

        Test.startTest();
        // More recent should come first (negative result)
        Integer result1 = record1.compareTo(record2);
        // Older should come later (positive result)
        Integer result2 = record2.compareTo(record1);
        // Equal dates
        Integer result3 = record1.compareTo(record1);
        // Null vs non-null
        Integer result4 = record3.compareTo(record1);
        Integer result5 = record1.compareTo(record3);
        // Both null
        Integer result6 = record3.compareTo(record4);
        Test.stopTest();

        System.assertEquals(-1, result1, 'More recent record should sort first');
        System.assertEquals(1, result2, 'Older record should sort last');
        System.assertEquals(0, result3, 'Same dates should be equal');
        System.assertEquals(1, result4, 'Null date should sort last');
        System.assertEquals(-1, result5, 'Non-null date should sort before null');
        System.assertEquals(0, result6, 'Two null dates should be equal');
    }

    @isTest
    static void testTimelineRecordFormatDate() {
        TimelineRecord record = new TimelineRecord();
        record.dateValue = DateTime.newInstance(2024, 1, 15, 15, 30, 0);

        Test.startTest();
        record.formatDate();
        Test.stopTest();

        System.assertNotEquals(null, record.dateFormatted, 'Formatted date should not be null');
        System.assert(record.dateFormatted.contains('Jan'), 'Formatted date should contain month');
        System.assert(record.dateFormatted.contains('15'), 'Formatted date should contain day');
        System.assert(record.dateFormatted.contains('2024'), 'Formatted date should contain year');
    }

    @isTest
    static void testTimelineRecordFormatDateNull() {
        TimelineRecord record = new TimelineRecord();
        record.dateValue = null;

        Test.startTest();
        record.formatDate();
        Test.stopTest();

        System.assertEquals(null, record.dateFormatted, 'Formatted date should be null for null dateValue');
    }

    @isTest
    static void testGetTimelineDataWithAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<TimelineRecord> records = TimelineHistoryController.getTimelineData(
            acc.Id,
            'Account',
            50,
            0
        );
        Test.stopTest();

        System.assertNotEquals(null, records, 'Records list should not be null');
    }

    @isTest
    static void testGetTimelineDataPagination() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        // First page
        List<TimelineRecord> page1 = TimelineHistoryController.getTimelineData(
            opp.Id,
            'Opportunity',
            10,
            0
        );

        // Second page
        List<TimelineRecord> page2 = TimelineHistoryController.getTimelineData(
            opp.Id,
            'Opportunity',
            10,
            10
        );
        Test.stopTest();

        System.assertNotEquals(null, page1, 'First page should not be null');
        System.assertNotEquals(null, page2, 'Second page should not be null');
    }
}
