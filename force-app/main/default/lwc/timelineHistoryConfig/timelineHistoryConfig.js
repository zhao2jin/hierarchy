import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChildConfigurations from '@salesforce/apex/TimelineConfigController.getChildConfigurations';
import getAvailableChildObjects from '@salesforce/apex/TimelineConfigController.getAvailableChildObjects';
import saveChildConfiguration from '@salesforce/apex/TimelineConfigController.saveChildConfiguration';
import deleteChildConfiguration from '@salesforce/apex/TimelineConfigController.deleteChildConfiguration';

// Map of object names to their standard icons
const OBJECT_ICON_MAP = {
    'Task': 'standard:task',
    'Event': 'standard:event',
    'Contact': 'standard:contact',
    'Account': 'standard:account',
    'Case': 'standard:case',
    'Lead': 'standard:lead',
    'Opportunity': 'standard:opportunity',
    'OpportunityLineItem': 'standard:opportunity_product',
    'OpportunityTeamMember': 'standard:team_member',
    'Contract': 'standard:contract',
    'Order': 'standard:order',
    'OrderItem': 'standard:order_item',
    'Quote': 'standard:quotes',
    'QuoteLineItem': 'standard:quote_line_item',
    'Note': 'standard:note',
    'Attachment': 'standard:file',
    'ContentDocument': 'standard:file',
    'EmailMessage': 'standard:email',
    'CampaignMember': 'standard:campaign_members',
    'AccountContactRole': 'standard:contact',
    'OpportunityContactRole': 'standard:contact',
    'CaseComment': 'standard:case_comment',
    'FeedItem': 'standard:feed',
    'User': 'standard:user',
    'Product2': 'standard:product',
    'Pricebook2': 'standard:pricebook',
    'Asset': 'standard:asset_object',
    'Solution': 'standard:solution'
};

/**
 * Configuration modal for Timeline History Component.
 * Allows admins to add and remove child object configurations.
 * Automatically detects relationship and field mappings.
 */
export default class TimelineHistoryConfig extends LightningElement {
    @api objectApiName;

    @track existingConfigs = [];
    @track availableObjects = [];

    isLoading = true;
    isSaving = false;
    showAddForm = false;
    relationshipError = '';

    // Form fields (auto-populated)
    selectedObject = '';
    selectedRelationshipField = '';
    childObjectLabel = '';

    /**
     * Wire adapter to get existing configurations
     */
    @wire(getChildConfigurations, { parentObjectApiName: '$objectApiName' })
    wiredConfigs({ error, data }) {
        if (data) {
            this.existingConfigs = data;
            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.isLoading = false;
        }
    }

    /**
     * Wire adapter to get available child objects
     */
    @wire(getAvailableChildObjects, { parentObjectApiName: '$objectApiName' })
    wiredObjects({ error, data }) {
        if (data) {
            this.availableObjects = data.map(obj => ({
                label: obj.label,
                value: obj.value,
                relationshipField: obj.relationshipField
            }));
        } else if (error) {
            console.error('Error fetching child objects:', error);
        }
    }

    /**
     * Check if there is a relationship error
     */
    get hasRelationshipError() {
        return Boolean(this.relationshipError);
    }

    /**
     * Get available object options, excluding already configured ones
     */
    get objectOptions() {
        const configuredObjects = this.existingConfigs
            .filter(c => c.isActive)
            .map(c => c.childObjectApiName);

        return this.availableObjects.filter(obj =>
            !configuredObjects.includes(obj.value)
        );
    }

    /**
     * Check if there are existing configurations
     */
    get hasConfigs() {
        return this.existingConfigs.length > 0;
    }

    /**
     * Get only active configurations
     */
    get activeConfigs() {
        return this.existingConfigs.filter(c => c.isActive);
    }

    /**
     * Check if add button should be disabled
     */
    get isAddDisabled() {
        return this.objectOptions.length === 0;
    }

    /**
     * Check if save button should be disabled
     */
    get isSaveDisabled() {
        return !this.selectedObject || !this.selectedRelationshipField || this.isSaving || this.hasRelationshipError;
    }

    /**
     * Get the appropriate icon for an object
     */
    getIconForObject(objectApiName) {
        // Check direct mapping first
        if (OBJECT_ICON_MAP[objectApiName]) {
            return OBJECT_ICON_MAP[objectApiName];
        }
        // For custom objects, use custom icon
        if (objectApiName.endsWith('__c')) {
            return 'standard:custom';
        }
        // Default
        return 'standard:record';
    }

    /**
     * Handle object selection change - auto-saves when valid object is selected
     */
    async handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.relationshipError = '';

        // Find the relationship field for the selected object
        const selectedObjData = this.availableObjects.find(
            obj => obj.value === this.selectedObject
        );

        if (selectedObjData) {
            if (!selectedObjData.relationshipField) {
                this.relationshipError = `No relationship found between ${this.objectApiName} and ${this.selectedObject}. This object cannot be added to the timeline.`;
                this.selectedRelationshipField = '';
                this.childObjectLabel = '';
            } else {
                this.selectedRelationshipField = selectedObjData.relationshipField;
                this.childObjectLabel = selectedObjData.label;
                // Auto-save when valid object is selected
                await this.saveConfiguration();
            }
        } else {
            this.relationshipError = 'Selected object not found in available relationships.';
            this.selectedRelationshipField = '';
            this.childObjectLabel = '';
        }
    }

    /**
     * Save the configuration
     */
    async saveConfiguration() {
        if (!this.selectedObject || !this.selectedRelationshipField) {
            return;
        }

        this.isSaving = true;

        const config = {
            parentObjectApiName: this.objectApiName,
            childObjectApiName: this.selectedObject,
            childObjectLabel: this.childObjectLabel,
            relationshipField: this.selectedRelationshipField,
            dateFieldApiName: 'CreatedDate',
            titleFieldApiName: 'Name',
            descriptionFieldApiName: '',
            iconName: this.getIconForObject(this.selectedObject),
            isActive: true
        };

        try {
            const recordId = await saveChildConfiguration({ config });

            // Add saved record to local list
            const newConfig = {
                id: recordId,
                developerName: `${this.objectApiName}_${this.selectedObject}`.replace(/[^a-zA-Z0-9_]/g, '_'),
                parentObjectApiName: this.objectApiName,
                childObjectApiName: this.selectedObject,
                childObjectLabel: this.childObjectLabel,
                relationshipField: this.selectedRelationshipField,
                iconName: this.getIconForObject(this.selectedObject),
                isActive: true
            };
            this.existingConfigs = [...this.existingConfigs, newConfig];

            this.showToast('Success',
                `${this.childObjectLabel} added to timeline.`,
                'success');

            this.showAddForm = false;
            this.resetForm();

            // Dispatch save event to parent
            this.dispatchEvent(new CustomEvent('save'));
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    /**
     * Show the add configuration form
     */
    handleShowAddForm() {
        this.resetForm();
        this.showAddForm = true;
    }

    /**
     * Cancel adding a new configuration
     */
    handleCancelAdd() {
        this.showAddForm = false;
        this.resetForm();
    }

    /**
     * Reset the form fields
     */
    resetForm() {
        this.selectedObject = '';
        this.selectedRelationshipField = '';
        this.childObjectLabel = '';
        this.relationshipError = '';
    }

    /**
     * Remove a configuration
     */
    async handleRemoveConfig(event) {
        const configId = event.currentTarget.dataset.configId;
        const configLabel = event.currentTarget.dataset.label;

        try {
            await deleteChildConfiguration({ configId });

            this.showToast('Success',
                `${configLabel} removed from timeline.`,
                'success');

            // Remove from local list
            this.existingConfigs = this.existingConfigs.filter(c => c.id !== configId);

            // Dispatch save event to parent
            this.dispatchEvent(new CustomEvent('save'));
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    /**
     * Close the modal
     */
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    /**
     * Show a toast message
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    /**
     * Extract error message from error object
     */
    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}
