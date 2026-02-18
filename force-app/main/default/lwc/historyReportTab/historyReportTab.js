import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfiguredObjects  from '@salesforce/apex/HistoryReportController.getConfiguredObjects';
import getHistoryReport      from '@salesforce/apex/HistoryReportController.getHistoryReport';
import getHistoryReportCount from '@salesforce/apex/HistoryReportController.getHistoryReportCount';

const PAGE_SIZE = 50;

const DATE_PRESETS = [
    { label: 'Last 7 Days',  value: 'last7'    },
    { label: 'Last 30 Days', value: 'last30'   },
    { label: 'Last 90 Days', value: 'last90'   },
    { label: 'Last Year',    value: 'lastYear' },
    { label: 'Year to Date', value: 'ytd'      }
];

const COLUMNS = [
    {
        label: 'Object',
        fieldName: 'objectLabel',
        type: 'text',
        sortable: true,
        initialWidth: 130
    },
    {
        label: 'Record',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'recordName' }, target: '_blank' },
        sortable: true,
        initialWidth: 440
    },
    {
        label: 'Field Changed',
        fieldName: 'fieldChanged',
        type: 'text',
        sortable: true,
        initialWidth: 170
    },
    {
        label: 'Old Value',
        fieldName: 'oldValue',
        type: 'text',
        wrapText: true,
        initialWidth: 110
    },
    {
        label: 'New Value',
        fieldName: 'newValue',
        type: 'text',
        wrapText: true
    },
    {
        label: 'Changed By',
        fieldName: 'changedBy',
        type: 'text',
        sortable: true,
        initialWidth: 170
    },
    {
        label: 'Date',
        fieldName: 'changedDate',
        type: 'date',
        typeAttributes: {
            year:   'numeric',
            month:  'short',
            day:    'numeric',
            hour:   '2-digit',
            minute: '2-digit'
        },
        sortable: true,
        initialWidth: 195
    }
];

export default class HistoryReportTab extends LightningElement {

    columns     = COLUMNS;
    pageSize    = PAGE_SIZE;
    datePresets = DATE_PRESETS;

    // ── Filter state ──────────────────────────────────────────────────────────
    @track selectedObjects  = [];
    startDate               = '';
    endDate                 = '';
    @track fieldFilter      = '';   // client-side
    @track changedByFilter  = '';   // client-side
    @track activePreset     = '';

    // ── Panel visibility ──────────────────────────────────────────────────────
    @track isFilterPanelOpen = true;

    // ── Data ──────────────────────────────────────────────────────────────────
    allLoadedData           = [];   // full server dataset (grows with Load More)
    @track tableData        = [];   // client-filtered view shown in the datatable
    @track totalCount       = null;
    @track hasMore          = false;
    @track hasSearched      = false;
    @track isPageLoading    = false;
    @track isTableLoading   = false;
    @track errorMessage     = '';

    // ── Sort state ────────────────────────────────────────────────────────────
    @track sortedBy        = 'changedDate';
    @track sortedDirection = 'desc';

    // ── Pagination cursor ─────────────────────────────────────────────────────
    currentOffset = 0;

    // ─────────────────────────── Wired data ──────────────────────────────────

    @wire(getConfiguredObjects)
    configuredObjects;

    // ─────────────────────────── Computed getters ────────────────────────────

    get objectOptions() {
        if (!this.configuredObjects?.data) return [];
        return this.configuredObjects.data.map(obj => ({
            label: obj.label,
            value: obj.value
        }));
    }

    get hasObjectOptions() {
        return this.objectOptions.length > 0;
    }

    get noObjectsConfigured() {
        return this.configuredObjects.data != null &&
               this.configuredObjects.data.length === 0;
    }

    get filterChevronIcon() {
        return this.isFilterPanelOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get isApplyDisabled() {
        return this.selectedObjects.length === 0 || this.isPageLoading;
    }

    get showEmptyState() {
        return this.hasSearched && this.tableData.length === 0 && !this.isPageLoading;
    }

    get showTable() {
        return this.hasSearched && this.tableData.length > 0;
    }

    get recordCountLabel() {
        if (this.totalCount === null) return '';
        const loaded  = this.allLoadedData.length;
        const shown   = this.tableData.length;
        const isFiltered = this.fieldFilter || this.changedByFilter;
        if (isFiltered) {
            return `Showing ${shown.toLocaleString()} filtered of ${loaded.toLocaleString()} loaded (${this.totalCount.toLocaleString()} total)`;
        }
        return `Showing ${loaded.toLocaleString()} of ${this.totalCount.toLocaleString()} records`;
    }

    get emptyStateMessage() {
        if (this.allLoadedData.length > 0) {
            return 'No records match your current Field Changed or Changed By filter.';
        }
        return 'No history records found. Try adjusting your filters, date range, or object selection.';
    }

    get hasError() {
        return this.errorMessage !== '';
    }

    get presetButtons() {
        return this.datePresets.map(p => ({
            ...p,
            variant: p.value === this.activePreset ? 'brand' : 'neutral'
        }));
    }

    /** Unique sorted field labels already present in the loaded dataset. */
    get fieldSuggestions() {
        const vals = new Set(this.allLoadedData.map(r => r.fieldChanged).filter(Boolean));
        return [...vals].sort();
    }

    /** Unique sorted user names already present in the loaded dataset. */
    get changedBySuggestions() {
        const vals = new Set(this.allLoadedData.map(r => r.changedBy).filter(Boolean));
        return [...vals].sort();
    }

    // ─────────────────────────── Event handlers ───────────────────────────────

    handleToggleFilters() {
        this.isFilterPanelOpen = !this.isFilterPanelOpen;
    }

    handleObjectSelection(event) {
        this.selectedObjects = event.detail.value;
    }

    handleStartDateChange(event) {
        this.startDate    = event.target.value;
        this.activePreset = '';
    }

    handleEndDateChange(event) {
        this.endDate      = event.target.value;
        this.activePreset = '';
    }

    handleDatePreset(event) {
        const preset = event.currentTarget.dataset.preset;
        const today  = new Date();

        this.activePreset = preset;
        this.endDate      = this._formatDate(today);

        switch (preset) {
            case 'last7':
                this.startDate = this._formatDate(this._daysAgo(today, 6));
                break;
            case 'last30':
                this.startDate = this._formatDate(this._daysAgo(today, 29));
                break;
            case 'last90':
                this.startDate = this._formatDate(this._daysAgo(today, 89));
                break;
            case 'lastYear': {
                const d = new Date(today);
                d.setFullYear(d.getFullYear() - 1);
                this.startDate = this._formatDate(d);
                break;
            }
            case 'ytd':
                this.startDate = `${today.getFullYear()}-01-01`;
                break;
            default:
                break;
        }

        this._syncDateInputs();
    }

    /** Client-side filter: fires on every keystroke, re-filters without a server call. */
    handleFieldFilterInput(event) {
        this.fieldFilter = event.target.value;
        this._applyClientFilters();
    }

    handleChangedByFilterInput(event) {
        this.changedByFilter = event.target.value;
        this._applyClientFilters();
    }

    async handleApplyFilters() {
        // Reset everything for a fresh server query
        this.allLoadedData = [];
        this.tableData     = [];
        this.currentOffset = 0;
        this.hasMore       = false;
        this.totalCount    = null;
        this.hasSearched   = false;
        this.errorMessage  = '';
        this.isPageLoading = true;

        try {
            const params = {
                selectedObjectApiNames: this.selectedObjects,
                startDateStr:           this.startDate,
                endDateStr:             this.endDate,
                limitCount:             PAGE_SIZE,
                offsetCount:            0
            };

            const [reportResult, count] = await Promise.all([
                getHistoryReport(params),
                getHistoryReportCount({
                    selectedObjectApiNames: this.selectedObjects,
                    startDateStr:           this.startDate,
                    endDateStr:             this.endDate
                })
            ]);

            this.allLoadedData = reportResult.records;
            this.hasMore       = reportResult.hasMore;
            this.totalCount    = count;
            this.hasSearched   = true;
            this._applyClientFilters();
        } catch (error) {
            this.errorMessage = this._extractMessage(error);
            this._showToast('Error loading history', this.errorMessage, 'error');
        } finally {
            this.isPageLoading = false;
        }
    }

    handleLoadMore() {
        if (!this.hasMore || this.isTableLoading) return;

        this.isTableLoading = true;
        this.currentOffset += PAGE_SIZE;

        getHistoryReport({
            selectedObjectApiNames: this.selectedObjects,
            startDateStr:           this.startDate,
            endDateStr:             this.endDate,
            limitCount:             PAGE_SIZE,
            offsetCount:            this.currentOffset
        })
        .then(result => {
            this.allLoadedData = [...this.allLoadedData, ...result.records];
            this.hasMore       = result.hasMore;
            this._applyClientFilters();
        })
        .catch(error => {
            this._showToast('Error loading more records', this._extractMessage(error), 'error');
        })
        .finally(() => {
            this.isTableLoading = false;
        });
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy        = fieldName;
        this.sortedDirection = sortDirection;

        const multiplier = sortDirection === 'asc' ? 1 : -1;
        this.tableData = [...this.tableData].sort((a, b) => {
            let valA = a[fieldName] ?? '';
            let valB = b[fieldName] ?? '';
            if (typeof valA === 'string') valA = valA.toLowerCase();
            if (typeof valB === 'string') valB = valB.toLowerCase();
            if (valA < valB) return -1 * multiplier;
            if (valA > valB) return  1 * multiplier;
            return 0;
        });
    }

    // ─────────────────────────── Private helpers ──────────────────────────────

    /**
     * Re-filters allLoadedData using the current fieldFilter and changedByFilter
     * and writes the result to tableData. Called after every server fetch and on
     * each filter keystroke — no server round-trip required.
     */
    _applyClientFilters() {
        let rows = this.allLoadedData;

        if (this.fieldFilter) {
            const q = this.fieldFilter.toLowerCase();
            rows = rows.filter(r => r.fieldChanged?.toLowerCase().includes(q));
        }
        if (this.changedByFilter) {
            const q = this.changedByFilter.toLowerCase();
            rows = rows.filter(r => r.changedBy?.toLowerCase().includes(q));
        }

        this.tableData = rows;
    }

    _formatDate(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    _daysAgo(from, days) {
        return new Date(from.getTime() - days * 24 * 60 * 60 * 1000);
    }

    _syncDateInputs() {
        const startInput = this.template.querySelector('lightning-input[name="startDate"]');
        const endInput   = this.template.querySelector('lightning-input[name="endDate"]');
        if (startInput) startInput.value = this.startDate;
        if (endInput)   endInput.value   = this.endDate;
    }

    _extractMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
