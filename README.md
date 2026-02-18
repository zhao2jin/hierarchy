# Timeline History Viewer

Configurable LWC package that displays field history for any sObject and its related child objects. Includes a record-page timeline and a standalone cross-object history report tab.

## Setup

### 1. Deploy

```bash
sf org login web --alias my-org
sf project deploy start --target-org my-org
```

### 2. Assign permission sets

```bash
# Admins (can configure child objects + run the report)
sf org assign permset --name Timeline_History_Admin --target-org my-org

# End users (view-only)
sf org assign permset --name Timeline_History_User --target-org my-org
```

### 3. Add the timeline to a record page

1. Open the record page in Lightning App Builder.
2. Drag **timelineHistoryViewer** onto the layout, save, and activate.

### 4. Configure child objects

1. On a record page with the component, click the gear icon (admins only).
2. Click **Add Child Object** and select a related object.

### 5. Add the History Report tab

1. In **Setup → App Manager**, edit the target app.
2. Under **Navigation Items**, add a new item → **Lightning Component** → **historyReportTab**.

Alternatively, drag **historyReportTab** onto any App Page in Lightning App Builder.

## Prerequisites

- Salesforce CLI (`sf`)
- Field history tracking enabled on every object you want to display
- Objects must have a `Name` field for record links in the report to resolve correctly

---

## Release Notes

### v1.0.0

- Record-page timeline (`timelineHistoryViewer`) combining parent field history and configured child object histories
- Admin configuration modal to add/remove child objects without code changes
- Object-type filter pills and paginated load-more on the timeline
- Standalone history report tab (`historyReportTab`) with cross-object, date-filtered results
- Server-side date filtering; client-side Field Changed and Changed By filters with autocomplete
- Infinite-scroll pagination with record count display
- Clickable Record column in the report links directly to the changed record
- Timeline entries are read-only (no in-place record navigation)
