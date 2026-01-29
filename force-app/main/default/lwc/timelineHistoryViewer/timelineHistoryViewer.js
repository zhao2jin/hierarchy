import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getTimelineData from '@salesforce/apex/TimelineHistoryController.getTimelineData';
import getTimelineRecordCount from '@salesforce/apex/TimelineHistoryController.getTimelineRecordCount';
import hasConfigPermission from '@salesforce/apex/TimelineHistoryController.hasConfigPermission';
import getAvailableObjectTypes from '@salesforce/apex/TimelineHistoryController.getAvailableObjectTypes';

/**
 * Main Timeline History Viewer component.
 * Displays a chronological timeline of history records and configured child objects.
 */
export default class TimelineHistoryViewer extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api title = '';
    @api maxRecords = 50;

    _showFilters = true;
    @api
    get showFilters() {
        return this._showFilters;
    }
    set showFilters(value) {
        this._showFilters = value !== false && value !== 'false';
    }

    @track timelineRecords = [];
    @track filteredRecords = [];
    @track objectTypes = [];
    @track selectedFilters = [];

    isLoading = true;
    hasError = false;
    errorMessage = '';
    hasConfigAccess = false;
    showConfigModal = false;
    totalRecordCount = 0;
    currentOffset = 0;
    hasMoreRecords = false;
    objectLabel = '';

    wiredTimelineResult;
    wiredCountResult;

    /**
     * Wire adapter to get object info for label
     */
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo({ error, data }) {
        if (data) {
            this.objectLabel = data.label;
        } else if (error) {
            console.error('Error fetching object info:', error);
            this.objectLabel = this.objectApiName;
        }
    }

    /**
     * Wire adapter to check config permission
     */
    @wire(hasConfigPermission)
    wiredPermission({ error, data }) {
        if (data !== undefined) {
            this.hasConfigAccess = data;
        } else if (error) {
            console.error('Error checking config permission:', error);
        }
    }

    /**
     * Wire adapter to get available object types for filtering
     */
    @wire(getAvailableObjectTypes, { recordId: '$recordId', objectApiName: '$objectApiName' })
    wiredObjectTypes({ error, data }) {
        if (data) {
            this.objectTypes = data.map(type => ({
                ...type,
                selected: true,
                variant: 'brand'
            }));
            this.selectedFilters = data.map(type => type.value);
        } else if (error) {
            console.error('Error fetching object types:', error);
        }
    }

    /**
     * Wire adapter to get total record count
     */
    @wire(getTimelineRecordCount, { recordId: '$recordId', objectApiName: '$objectApiName' })
    wiredRecordCount(result) {
        this.wiredCountResult = result;
        const { error, data } = result;
        if (data !== undefined) {
            this.totalRecordCount = data;
        } else if (error) {
            console.error('Error fetching record count:', error);
        }
    }

    /**
     * Wire adapter to get timeline data
     */
    @wire(getTimelineData, {
        recordId: '$recordId',
        objectApiName: '$objectApiName',
        limitCount: '$maxRecords',
        offsetCount: 0
    })
    wiredTimeline(result) {
        this.wiredTimelineResult = result;
        const { error, data } = result;
        this.isLoading = false;

        if (data) {
            this.timelineRecords = data;
            this.applyFilters();
            this.hasError = false;
            this.currentOffset = data.length;
            this.hasMoreRecords = this.currentOffset < this.totalRecordCount;
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.getErrorMessage(error);
            console.error('Error fetching timeline data:', error);
        }
    }

    /**
     * Check if there are any records to display
     */
    get hasRecords() {
        return this.filteredRecords && this.filteredRecords.length > 0;
    }

    /**
     * Check if the component is ready (not loading and no error)
     */
    get isReady() {
        return !this.isLoading && !this.hasError;
    }

    /**
     * Get the empty state message
     */
    get emptyMessage() {
        if (this.selectedFilters.length === 0) {
            return 'No filters selected. Please select at least one object type to view.';
        }
        return 'No timeline records found for this record.';
    }

    /**
     * Check if filters are available
     */
    get hasFilters() {
        return this.showFilters && this.objectTypes.length > 0;
    }

    /**
     * Get the header title with record count
     * Uses custom title if provided, otherwise uses "{Object Label} History"
     */
    get headerTitle() {
        const title = this.title || (this.objectLabel ? `${this.objectLabel} History` : 'History');
        if (this.totalRecordCount > 0) {
            return `${title} (${this.filteredRecords.length})`;
        }
        return title;
    }

    /**
     * Apply selected filters to timeline records
     */
    applyFilters() {
        if (this.selectedFilters.length === 0) {
            this.filteredRecords = [];
        } else {
            this.filteredRecords = this.timelineRecords.filter(record =>
                this.selectedFilters.includes(record.objectApiName)
            );
        }
    }

    /**
     * Handle filter button click
     */
    handleFilterClick(event) {
        const filterValue = event.currentTarget.dataset.value;
        const index = this.objectTypes.findIndex(type => type.value === filterValue);

        if (index !== -1) {
            const isSelected = !this.objectTypes[index].selected;
            this.objectTypes[index] = {
                ...this.objectTypes[index],
                selected: isSelected,
                variant: isSelected ? 'brand' : 'neutral'
            };
            this.objectTypes = [...this.objectTypes];

            if (isSelected) {
                this.selectedFilters = [...this.selectedFilters, filterValue];
            } else {
                this.selectedFilters = this.selectedFilters.filter(f => f !== filterValue);
            }

            this.applyFilters();
        }
    }

    /**
     * Handle "Select All" filters
     */
    handleSelectAll() {
        this.objectTypes = this.objectTypes.map(type => ({
            ...type,
            selected: true,
            variant: 'brand'
        }));
        this.selectedFilters = this.objectTypes.map(type => type.value);
        this.applyFilters();
    }

    /**
     * Handle "Clear All" filters
     */
    handleClearAll() {
        this.objectTypes = this.objectTypes.map(type => ({
            ...type,
            selected: false,
            variant: 'neutral'
        }));
        this.selectedFilters = [];
        this.applyFilters();
    }

    /**
     * Handle "Load More" button click
     */
    async handleLoadMore() {
        if (!this.hasMoreRecords) return;

        this.isLoading = true;

        try {
            const moreRecords = await getTimelineData({
                recordId: this.recordId,
                objectApiName: this.objectApiName,
                limitCount: this.maxRecords,
                offsetCount: this.currentOffset
            });

            if (moreRecords && moreRecords.length > 0) {
                this.timelineRecords = [...this.timelineRecords, ...moreRecords];
                this.currentOffset += moreRecords.length;
                this.hasMoreRecords = this.currentOffset < this.totalRecordCount;
                this.applyFilters();
            } else {
                this.hasMoreRecords = false;
            }
        } catch (error) {
            console.error('Error loading more records:', error);
            this.hasError = true;
            this.errorMessage = this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Handle configuration button click
     */
    handleConfigClick() {
        this.showConfigModal = true;
    }

    /**
     * Handle configuration modal close
     */
    handleConfigClose() {
        this.showConfigModal = false;
    }

    /**
     * Handle configuration saved - refresh data
     */
    handleConfigSaved() {
        this.showConfigModal = false;
        this.refreshData();
    }

    /**
     * Handle refresh button click
     */
    handleRefresh() {
        this.refreshData();
    }

    /**
     * Refresh all data
     */
    async refreshData() {
        this.isLoading = true;
        this.currentOffset = 0;

        try {
            await Promise.all([
                refreshApex(this.wiredTimelineResult),
                refreshApex(this.wiredCountResult)
            ]);
        } catch (error) {
            console.error('Error refreshing data:', error);
        } finally {
            this.isLoading = false;
        }
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
