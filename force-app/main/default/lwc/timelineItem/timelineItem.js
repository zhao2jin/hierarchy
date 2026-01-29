import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

/**
 * Individual timeline item component that displays a single record in the timeline.
 * Uses SLDS timeline item markup for consistent styling.
 */
export default class TimelineItem extends NavigationMixin(LightningElement) {
    @api record;

    /**
     * Get the record ID
     */
    get recordId() {
        return this.record?.id;
    }

    /**
     * Get the object API name
     */
    get objectApiName() {
        return this.record?.objectApiName;
    }

    /**
     * Get the object label for display
     */
    get objectLabel() {
        return this.record?.objectLabel || this.record?.objectApiName;
    }

    /**
     * Get the title text
     */
    get title() {
        return this.record?.title || 'Untitled';
    }

    /**
     * Get the description text
     */
    get description() {
        return this.record?.description || '';
    }

    /**
     * Check if description exists
     */
    get hasDescription() {
        return Boolean(this.record?.description);
    }

    /**
     * Get the formatted date
     */
    get dateFormatted() {
        return this.record?.dateFormatted || '';
    }

    /**
     * Get the icon name
     */
    get iconName() {
        return this.record?.iconName || 'standard:record';
    }

    /**
     * Get the record URL
     */
    get recordUrl() {
        return this.record?.recordUrl;
    }

    /**
     * Check if record is navigable (has a valid URL)
     */
    get isNavigable() {
        return Boolean(this.record?.recordUrl) && this.record?.recordType !== 'history';
    }

    /**
     * Check if this is a history record
     */
    get isHistoryRecord() {
        return this.record?.recordType === 'history';
    }

    /**
     * Get the icon container class based on record type
     */
    get iconContainerClass() {
        const baseClass = 'slds-timeline__icon';
        if (this.isHistoryRecord) {
            return `${baseClass} slds-timeline__icon_history`;
        }
        return baseClass;
    }

    /**
     * Get the created by name if available
     */
    get createdByName() {
        return this.record?.additionalFields?.createdByName || '';
    }

    /**
     * Check if created by info is available
     */
    get hasCreatedBy() {
        return Boolean(this.record?.additionalFields?.createdByName);
    }

    /**
     * Handle click on the record title to navigate
     */
    handleTitleClick(event) {
        if (this.isNavigable && this.recordId) {
            event.preventDefault();
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    actionName: 'view'
                }
            });
        }
    }

    /**
     * Handle keyboard navigation
     */
    handleKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.handleTitleClick(event);
        }
    }
}
