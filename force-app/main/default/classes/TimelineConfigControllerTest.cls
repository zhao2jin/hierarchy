/**
 * @description Test class for TimelineConfigController
 */
@isTest
private class TimelineConfigControllerTest {

    @isTest
    static void testGetChildConfigurations() {
        // Insert test custom setting record
        Timeline_Child_Config__c config = new Timeline_Child_Config__c(
            Name = 'TestConfig',
            Parent_Object_API_Name__c = 'Opportunity',
            Child_Object_API_Name__c = 'OpportunityLineItem',
            Child_Object_Label__c = 'Opportunity Product',
            Relationship_Field__c = 'OpportunityId',
            Icon_Name__c = 'standard:opportunity_product',
            Is_Active__c = true
        );
        insert config;

        Test.startTest();
        List<TimelineConfigController.TimelineConfigWrapper> configs =
            TimelineConfigController.getChildConfigurations('Opportunity');
        Test.stopTest();

        System.assertEquals(1, configs.size(), 'Should return 1 config');
        System.assertEquals('OpportunityLineItem', configs[0].childObjectApiName);
        System.assertEquals('Opportunity Product', configs[0].childObjectLabel);
    }

    @isTest
    static void testGetChildConfigurationsWithNullParam() {
        Test.startTest();
        List<TimelineConfigController.TimelineConfigWrapper> configs =
            TimelineConfigController.getChildConfigurations(null);
        Test.stopTest();

        System.assertEquals(0, configs.size(), 'Should return empty list for null param');
    }

    @isTest
    static void testGetChildConfigurationsWithBlankParam() {
        Test.startTest();
        List<TimelineConfigController.TimelineConfigWrapper> configs =
            TimelineConfigController.getChildConfigurations('');
        Test.stopTest();

        System.assertEquals(0, configs.size(), 'Should return empty list for blank param');
    }

    @isTest
    static void testGetAvailableChildObjects() {
        Test.startTest();
        List<TimelineConfigController.ObjectOption> objects =
            TimelineConfigController.getAvailableChildObjects('Opportunity');
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Objects list should not be null');
    }

    @isTest
    static void testGetAvailableChildObjectsWithNullParam() {
        Test.startTest();
        List<TimelineConfigController.ObjectOption> objects =
            TimelineConfigController.getAvailableChildObjects(null);
        Test.stopTest();

        System.assertEquals(0, objects.size(), 'Should return empty list for null param');
    }

    @isTest
    static void testGetAvailableChildObjectsWithInvalidObject() {
        Test.startTest();
        List<TimelineConfigController.ObjectOption> objects =
            TimelineConfigController.getAvailableChildObjects('InvalidObject__c');
        Test.stopTest();

        System.assertEquals(0, objects.size(), 'Should return empty list for invalid object');
    }

    @isTest
    static void testGetAvailableChildObjectsForAccount() {
        Test.startTest();
        List<TimelineConfigController.ObjectOption> objects =
            TimelineConfigController.getAvailableChildObjects('Account');
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Objects list should not be null');
    }

    @isTest
    static void testGetAvailableChildObjectsContact() {
        Test.startTest();
        List<TimelineConfigController.ObjectOption> objects =
            TimelineConfigController.getAvailableChildObjects('Contact');
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Objects list should not be null');
    }

    @isTest
    static void testGetAvailableChildObjectsLead() {
        Test.startTest();
        List<TimelineConfigController.ObjectOption> objects =
            TimelineConfigController.getAvailableChildObjects('Lead');
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Objects list should not be null');
    }

    @isTest
    static void testSaveChildConfigurationWithoutPermission() {
        TimelineConfigController.TimelineConfigWrapper config =
            new TimelineConfigController.TimelineConfigWrapper();
        config.parentObjectApiName = 'Opportunity';
        config.childObjectApiName = 'Task';
        config.relationshipField = 'WhatId';

        Test.startTest();
        try {
            TimelineConfigController.saveChildConfiguration(config);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permission'),
                'Should throw permission error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveChildConfigurationWithMissingFields() {
        TimelineConfigController.TimelineConfigWrapper config =
            new TimelineConfigController.TimelineConfigWrapper();
        // Missing required fields

        Test.startTest();
        try {
            TimelineConfigController.saveChildConfiguration(config);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'),
                'Should throw validation error');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteChildConfigurationWithoutPermission() {
        // Insert a record to try deleting
        Timeline_Child_Config__c config = new Timeline_Child_Config__c(
            Name = 'TestDelete',
            Parent_Object_API_Name__c = 'Opportunity',
            Child_Object_API_Name__c = 'Task',
            Child_Object_Label__c = 'Task',
            Relationship_Field__c = 'WhatId',
            Is_Active__c = true
        );
        insert config;

        Test.startTest();
        try {
            TimelineConfigController.deleteChildConfiguration(config.Id);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permission'),
                'Should throw permission error');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteChildConfigurationWithBlankId() {
        Test.startTest();
        try {
            TimelineConfigController.deleteChildConfiguration('');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'),
                'Should throw validation error');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteChildConfigurationNotFound() {
        Test.startTest();
        try {
            // Use a fake but valid-format Id
            TimelineConfigController.deleteChildConfiguration('a0000000000000AAAA');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found') || e.getMessage().contains('Configuration'),
                'Should throw not found error');
        }
        Test.stopTest();
    }

    @isTest
    static void testTimelineConfigWrapperConstructor() {
        TimelineConfigController.TimelineConfigWrapper wrapper =
            new TimelineConfigController.TimelineConfigWrapper();

        System.assertEquals(true, wrapper.isActive, 'Default isActive should be true');
    }

    @isTest
    static void testTimelineConfigWrapperFromRecord() {
        Timeline_Child_Config__c rec = new Timeline_Child_Config__c(
            Name = 'TestWrapper',
            Parent_Object_API_Name__c = 'Account',
            Child_Object_API_Name__c = 'Contact',
            Child_Object_Label__c = 'Contact',
            Relationship_Field__c = 'AccountId',
            Icon_Name__c = 'standard:contact',
            Is_Active__c = true
        );
        insert rec;

        // Re-query to get the Id
        rec = [SELECT Id, Name, Parent_Object_API_Name__c, Child_Object_API_Name__c,
                      Child_Object_Label__c, Relationship_Field__c, Icon_Name__c, Is_Active__c
               FROM Timeline_Child_Config__c WHERE Name = 'TestWrapper' LIMIT 1];

        Test.startTest();
        TimelineConfigController.TimelineConfigWrapper wrapper =
            new TimelineConfigController.TimelineConfigWrapper(rec);
        Test.stopTest();

        System.assertEquals(rec.Id, wrapper.id);
        System.assertEquals('TestWrapper', wrapper.developerName);
        System.assertEquals('Account', wrapper.parentObjectApiName);
        System.assertEquals('Contact', wrapper.childObjectApiName);
        System.assertEquals('standard:contact', wrapper.iconName);
        System.assertEquals(true, wrapper.isActive);
    }

    @isTest
    static void testObjectOptionComparable() {
        TimelineConfigController.ObjectOption option1 = new TimelineConfigController.ObjectOption();
        option1.label = 'Alpha';

        TimelineConfigController.ObjectOption option2 = new TimelineConfigController.ObjectOption();
        option2.label = 'Beta';

        Test.startTest();
        Integer result = option1.compareTo(option2);
        Test.stopTest();

        System.assert(result < 0, 'Alpha should come before Beta');
    }
}
