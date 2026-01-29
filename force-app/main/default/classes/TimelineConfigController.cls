/**
 * @description Controller for Timeline History Component configuration.
 * Provides methods to manage child object configurations stored in the
 * Timeline_Child_Config__c custom setting and retrieve schema metadata.
 */
public with sharing class TimelineConfigController {

    /**
     * @description Get all child object configurations for a parent object
     * @param parentObjectApiName The API name of the parent object
     * @return List<TimelineConfigWrapper> List of configuration records
     */
    @AuraEnabled(cacheable=true)
    public static List<TimelineConfigWrapper> getChildConfigurations(String parentObjectApiName) {
        List<TimelineConfigWrapper> configs = new List<TimelineConfigWrapper>();

        if (String.isBlank(parentObjectApiName)) {
            return configs;
        }

        List<Timeline_Child_Config__c> records = [
            SELECT Id, Name, Parent_Object_API_Name__c,
                   Child_Object_API_Name__c, Child_Object_Label__c,
                   Relationship_Field__c, Icon_Name__c, Is_Active__c
            FROM Timeline_Child_Config__c
            WHERE Parent_Object_API_Name__c = :parentObjectApiName
            ORDER BY Child_Object_Label__c
        ];

        for (Timeline_Child_Config__c rec : records) {
            configs.add(new TimelineConfigWrapper(rec));
        }

        return configs;
    }

    /**
     * @description Get available child objects that can be related to a parent object.
     * Only returns objects that have history tracking enabled.
     * @param parentObjectApiName The API name of the parent object
     * @return List<ObjectOption> List of related objects with their metadata
     */
    @AuraEnabled(cacheable=true)
    public static List<ObjectOption> getAvailableChildObjects(String parentObjectApiName) {
        List<ObjectOption> options = new List<ObjectOption>();

        if (String.isBlank(parentObjectApiName)) {
            return options;
        }

        Schema.SObjectType parentType = Schema.getGlobalDescribe().get(parentObjectApiName);
        if (parentType == null) {
            return options;
        }

        // Get child relationships
        Schema.DescribeSObjectResult parentDescribe = parentType.getDescribe();
        List<Schema.ChildRelationship> childRelationships = parentDescribe.getChildRelationships();

        Set<String> addedObjects = new Set<String>();

        for (Schema.ChildRelationship rel : childRelationships) {
            Schema.SObjectType childType = rel.getChildSObject();
            String childApiName = childType.getDescribe().getName();

            // Skip if already added or if it's a history/feed/share object
            if (addedObjects.contains(childApiName) ||
                childApiName.endsWith('History') ||
                childApiName.endsWith('Feed') ||
                childApiName.endsWith('Share') ||
                childApiName.endsWith('ChangeEvent')) {
                continue;
            }

            // Check if object is queryable and accessible
            Schema.DescribeSObjectResult childDescribe = childType.getDescribe();
            if (!childDescribe.isQueryable() || !childDescribe.isAccessible()) {
                continue;
            }

            // Check if history tracking is enabled for this object
            String historyObjectName = getHistoryObjectName(childApiName);
            Schema.SObjectType historyType = Schema.getGlobalDescribe().get(historyObjectName);
            if (historyType == null) {
                // Skip objects without history tracking
                continue;
            }

            ObjectOption option = new ObjectOption();
            option.value = childApiName;
            option.label = childDescribe.getLabel();
            option.relationshipField = String.valueOf(rel.getField());
            option.relationshipName = rel.getRelationshipName();

            options.add(option);
            addedObjects.add(childApiName);
        }

        // Also add common related objects that might use polymorphic relationships
        addPolymorphicObjects(parentObjectApiName, options, addedObjects);

        options.sort();
        return options;
    }

    /**
     * @description Save a new child object configuration using standard DML
     * @param config The configuration wrapper to save
     * @return String The record Id of the saved configuration
     */
    @AuraEnabled
    public static String saveChildConfiguration(TimelineConfigWrapper config) {
        // Validate required fields
        if (String.isBlank(config.parentObjectApiName) ||
            String.isBlank(config.childObjectApiName) ||
            String.isBlank(config.relationshipField)) {
            throw new AuraHandledException('Parent Object, Child Object, and Relationship Field are required.');
        }

        // Check permission
        if (!FeatureManagement.checkPermission('Modify_Timeline_Config')) {
            throw new AuraHandledException('You do not have permission to modify timeline configuration.');
        }

        // Generate a unique Name for the custom setting record
        String recordName = config.parentObjectApiName.replace('__c', '') + '_' +
                           config.childObjectApiName.replace('__c', '');
        recordName = recordName.replaceAll('[^a-zA-Z0-9_]', '_');
        // Custom Setting Name field is limited to 38 characters
        if (recordName.length() > 38) {
            recordName = recordName.substring(0, 38);
        }

        // Check for existing record with same name and make unique if needed
        List<Timeline_Child_Config__c> existing = [
            SELECT Id FROM Timeline_Child_Config__c WHERE Name = :recordName LIMIT 1
        ];
        if (!existing.isEmpty()) {
            // Append a numeric suffix
            String baseName = recordName.length() > 34 ? recordName.substring(0, 34) : recordName;
            Integer suffix = 1;
            String candidateName = baseName + '_' + suffix;
            while (!([SELECT Id FROM Timeline_Child_Config__c WHERE Name = :candidateName LIMIT 1]).isEmpty()) {
                suffix++;
                candidateName = baseName + '_' + suffix;
            }
            recordName = candidateName;
        }

        Timeline_Child_Config__c setting = new Timeline_Child_Config__c();
        setting.Name = recordName;
        setting.Parent_Object_API_Name__c = config.parentObjectApiName;
        setting.Child_Object_API_Name__c = config.childObjectApiName;
        setting.Child_Object_Label__c = String.isNotBlank(config.childObjectLabel)
            ? config.childObjectLabel
            : config.childObjectApiName;
        setting.Relationship_Field__c = config.relationshipField;
        setting.Icon_Name__c = String.isNotBlank(config.iconName)
            ? config.iconName
            : 'standard:record';
        setting.Is_Active__c = true;

        insert setting;

        return setting.Id;
    }

    /**
     * @description Delete a child object configuration
     * @param configId The record Id of the configuration to delete
     * @return Boolean True if successful
     */
    @AuraEnabled
    public static Boolean deleteChildConfiguration(String configId) {
        if (String.isBlank(configId)) {
            throw new AuraHandledException('Configuration Id is required.');
        }

        // Check permission
        if (!FeatureManagement.checkPermission('Modify_Timeline_Config')) {
            throw new AuraHandledException('You do not have permission to modify timeline configuration.');
        }

        List<Timeline_Child_Config__c> existing = [
            SELECT Id FROM Timeline_Child_Config__c WHERE Id = :configId LIMIT 1
        ];

        if (existing.isEmpty()) {
            throw new AuraHandledException('Configuration not found.');
        }

        delete existing;

        return true;
    }

    /**
     * @description Add polymorphic relationship objects like Task and Event
     */
    private static void addPolymorphicObjects(String parentObjectApiName,
                                              List<ObjectOption> options,
                                              Set<String> addedObjects) {
        // Task and Event use WhatId for most standard objects
        Set<String> whatIdObjects = new Set<String>{
            'Account', 'Opportunity', 'Case', 'Campaign', 'Contract', 'Order', 'Solution'
        };

        // Task and Event use WhoId for Person objects
        Set<String> whoIdObjects = new Set<String>{'Contact', 'Lead'};

        String relationshipField = null;
        if (whatIdObjects.contains(parentObjectApiName) || parentObjectApiName.endsWith('__c')) {
            relationshipField = 'WhatId';
        } else if (whoIdObjects.contains(parentObjectApiName)) {
            relationshipField = 'WhoId';
        }

        if (relationshipField != null) {
            // Only add Task if it has history tracking enabled
            if (!addedObjects.contains('Task')) {
                String taskHistoryName = getHistoryObjectName('Task');
                Schema.SObjectType taskHistoryType = Schema.getGlobalDescribe().get(taskHistoryName);
                if (taskHistoryType != null) {
                    ObjectOption taskOption = new ObjectOption();
                    taskOption.value = 'Task';
                    taskOption.label = 'Task';
                    taskOption.relationshipField = relationshipField;
                    taskOption.relationshipName = 'Tasks';
                    options.add(taskOption);
                    addedObjects.add('Task');
                }
            }

            // Only add Event if it has history tracking enabled
            if (!addedObjects.contains('Event')) {
                String eventHistoryName = getHistoryObjectName('Event');
                Schema.SObjectType eventHistoryType = Schema.getGlobalDescribe().get(eventHistoryName);
                if (eventHistoryType != null) {
                    ObjectOption eventOption = new ObjectOption();
                    eventOption.value = 'Event';
                    eventOption.label = 'Event';
                    eventOption.relationshipField = relationshipField;
                    eventOption.relationshipName = 'Events';
                    options.add(eventOption);
                    addedObjects.add('Event');
                }
            }
        }
    }

    /**
     * @description Get the history object name for a given object
     * Standard objects: AccountHistory, OpportunityHistory
     * Custom objects: MyObject__History (not MyObject__cHistory)
     */
    private static String getHistoryObjectName(String objectApiName) {
        if (objectApiName.endsWith('__c')) {
            return objectApiName.removeEnd('__c') + '__History';
        }
        return objectApiName + 'History';
    }

    /**
     * @description Wrapper class for timeline configuration
     */
    public class TimelineConfigWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public String parentObjectApiName { get; set; }
        @AuraEnabled public String childObjectApiName { get; set; }
        @AuraEnabled public String childObjectLabel { get; set; }
        @AuraEnabled public String relationshipField { get; set; }
        @AuraEnabled public String iconName { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }

        public TimelineConfigWrapper() {
            this.isActive = true;
        }

        public TimelineConfigWrapper(Timeline_Child_Config__c rec) {
            this.id = rec.Id;
            this.developerName = rec.Name;
            this.parentObjectApiName = rec.Parent_Object_API_Name__c;
            this.childObjectApiName = rec.Child_Object_API_Name__c;
            this.childObjectLabel = rec.Child_Object_Label__c;
            this.relationshipField = rec.Relationship_Field__c;
            this.iconName = rec.Icon_Name__c;
            this.isActive = rec.Is_Active__c;
        }
    }

    /**
     * @description Wrapper class for object options
     */
    public class ObjectOption implements Comparable {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String relationshipField { get; set; }
        @AuraEnabled public String relationshipName { get; set; }

        public Integer compareTo(Object compareTo) {
            ObjectOption other = (ObjectOption) compareTo;
            return this.label.compareTo(other.label);
        }
    }
}
