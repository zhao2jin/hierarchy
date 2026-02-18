import { LightningElement, api } from 'lwc';

/**
 * Individual timeline item component that displays a single record in the timeline.
 * Uses SLDS timeline item markup for consistent styling.
 */
export default class TimelineItem extends LightningElement {
    @api record;

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
     * Check if description exists
     */
    get hasDescription() {
        return Boolean(this.record?.description);
    }

    /**
     * Get the description text
     */
    get description() {
        return this.record?.description || '';
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
}
