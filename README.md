# Timeline History Viewer

A configurable Lightning Web Component package that displays field history records from any sObject and its related child objects. Includes a record-page timeline and a standalone cross-object history report tab.

## Features

### Timeline History Viewer (record page)
- Combines parent object field history with child object histories in a single chronological timeline
- Timeline entries are read-only — each entry shows what changed, when, and by whom
- Admins can add/remove child objects directly from the component — no code changes needed
- Auto-detects relationship fields, labels, and icons when adding a child object
- Filter by object type and paginate through large record sets

### History Report Tab (app page / tab)
- Cross-object history report not bound to a single record
- Object picker (multi-select) populated from existing Timeline configurations
- Quick date presets: Last 7 Days, Last 30 Days, Last 90 Days, Last Year, Year to Date
- Custom date range (From / To) filters
- Client-side **Field Changed** filter with autocomplete from loaded data (searches field labels)
- Client-side **Changed By** filter with autocomplete from loaded data (searches user names)
- Collapsible filter panel to maximise grid space after running a search
- `lightning-datatable` with infinite-scroll pagination for large data volumes
- Clickable **Record** column links directly to the changed record
- Showing X of Y record count with filtered vs loaded breakdown

## Components

| Component | Type | Target |
|---|---|---|
| `timelineHistoryViewer` | LWC | Record page, App page |
| `timelineHistoryConfig` | LWC (modal) | Internal — used by timelineHistoryViewer |
| `timelineItem` | LWC | Internal — used by timelineHistoryViewer |
| `historyReportTab` | LWC | App page, Lightning Tab |

## Apex Classes

| Class | Purpose |
|---|---|
| `TimelineHistoryController` | Fetches paginated history data for the record-page timeline |
| `TimelineConfigController` | Manages `Timeline_Child_Config__c` configuration records |
| `HistoryReportController` | Fetches cross-object paginated history for the report tab |
| `TimelineRecord` | Wrapper class (Comparable) for unified timeline rows |

## Setup

### 1. Deploy to your org

```bash
sf org login web --alias my-org
sf project deploy start --target-org my-org
```

### 2. Assign permission sets

```bash
# For admins who can configure child objects and run the history report
sf org assign permset --name Timeline_History_Admin --target-org my-org

# For users who only need to view the timeline on record pages
sf org assign permset --name Timeline_History_User --target-org my-org
```

**Permission set summary:**

| Permission Set | Apex Access | Custom Permission | Intended For |
|---|---|---|---|
| `Timeline_History_Admin` | All three controllers | `Modify_Timeline_Config` | Admins who configure and report |
| `Timeline_History_User` | All three controllers | — | End users viewing timelines |

### 3. Add the timeline to a record page

1. Navigate to any record page and open **Edit Page** in Lightning App Builder.
2. Drag **timelineHistoryViewer** onto the layout.
3. Save and activate the page.

### 4. Configure child objects

1. On a record page with the component, click the gear icon (visible to admins only).
2. Click **Add Child Object** and select a related object from the dropdown.
3. The child object's field history will appear in the timeline immediately.

### 5. Add the History Report tab to an app

1. In **Setup → App Manager**, edit the target Lightning app.
2. Go to the **Navigation Items** tab and add a new nav item.
3. Choose **Lightning Component** → select **historyReportTab**.
4. Save and open the app — the **History Report** tab appears in the nav bar.

Alternatively, in Lightning App Builder open any **App Page**, drag the **historyReportTab** component onto the canvas, save, and activate.

## Using the History Report

1. **Select objects** — move one or more objects from *Available* to *Selected* in the dual-listbox. The list shows every object that has been configured across all Timeline History Viewer instances in the org.
2. **Set a date range** — use the quick-date buttons (Last 7 Days, etc.) or type custom From/To dates. A date range is strongly recommended for large orgs.
3. **Apply Filters** — loads the first page of results. The total record count appears above the grid.
4. **Filter in-grid** — type in **Field Changed** or **Changed By** to instantly narrow visible rows. Both inputs offer autocomplete based on values already in the grid (field labels and user names). These filters do not trigger a new server query.
5. **Load more** — scroll to the bottom of the results grid to automatically load the next page.
6. **Collapse filters** — click the **Filters** header to hide the filter panel and give the grid more vertical space.

## Data model

### `Timeline_Child_Config__c` (List Custom Setting)

Stores which child objects appear in a parent object's timeline. Also drives the object list in the History Report tab.

| Field | Type | Description |
|---|---|---|
| `Parent_Object_API_Name__c` | Text | API name of the parent object (e.g. `Opportunity`) |
| `Child_Object_API_Name__c` | Text | API name of the child object (e.g. `Task`) |
| `Child_Object_Label__c` | Text | Display label shown in the UI |
| `Relationship_Field__c` | Text | Lookup field linking child to parent (e.g. `WhatId`) |
| `Icon_Name__c` | Text | SLDS icon (e.g. `standard:task`) |
| `Is_Active__c` | Checkbox | Enables or disables this configuration |

### `Modify_Timeline_Config` (Custom Permission)

Gates the ability to add/remove child objects from the timeline configuration modal. Included in `Timeline_History_Admin`.

## Prerequisites

- Salesforce CLI (`sf`)
- Field history tracking enabled on every object you want to display
- Objects must have a `Name` field (or equivalent) for the history report record links to resolve correctly
