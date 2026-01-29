/**
 * @description Wrapper class representing a single record in the timeline view.
 * Used to unify data from various objects (history, child objects) into a consistent format.
 */
public with sharing class TimelineRecord implements Comparable {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String objectApiName { get; set; }
    @AuraEnabled public String objectLabel { get; set; }
    @AuraEnabled public String title { get; set; }
    @AuraEnabled public String description { get; set; }
    @AuraEnabled public Datetime dateValue { get; set; }
    @AuraEnabled public String dateFormatted { get; set; }
    @AuraEnabled public String iconName { get; set; }
    @AuraEnabled public String recordUrl { get; set; }
    @AuraEnabled public String recordType { get; set; }
    @AuraEnabled public Map<String, Object> additionalFields { get; set; }

    public TimelineRecord() {
        this.additionalFields = new Map<String, Object>();
    }

    /**
     * @description Compare timeline records by date for sorting (most recent first)
     * @param compareTo The object to compare to
     * @return Integer - negative if this is more recent, positive if less recent, 0 if equal
     */
    public Integer compareTo(Object compareTo) {
        TimelineRecord other = (TimelineRecord) compareTo;
        if (this.dateValue == null && other.dateValue == null) {
            return 0;
        }
        if (this.dateValue == null) {
            return 1;
        }
        if (other.dateValue == null) {
            return -1;
        }
        // Sort descending (most recent first)
        if (this.dateValue > other.dateValue) {
            return -1;
        }
        if (this.dateValue < other.dateValue) {
            return 1;
        }
        return 0;
    }

    /**
     * @description Format the date value for display
     */
    public void formatDate() {
        if (this.dateValue != null) {
            // Format: "Jan 15, 2024 at 3:30 PM"
            this.dateFormatted = this.dateValue.format('MMM d, yyyy \'at\' h:mm a');
        }
    }
}
