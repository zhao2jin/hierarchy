# Timeline History Viewer

A configurable Lightning Web Component that displays field history records from any sObject and its related child objects in a unified, chronological timeline.

## Features

- Combines parent object field history with child object histories in a single timeline
- Admins can add/remove child objects directly from the component -- no code changes needed
- Auto-detects relationship fields, labels, and icons when adding a child object
- Filter by object type and paginate through large record sets

## Setup

### 1. Deploy to your org

```bash
sf org login web --alias my-org
sf project deploy start --target-org my-org
```

### 2. Assign permission sets

```bash
# For admins who can configure child objects
sf org assign permset --name Timeline_History_Admin --target-org my-org

# For users who only need to view the timeline
sf org assign permset --name Timeline_History_User --target-org my-org
```

### 3. Add the component to a record page

1. Navigate to any record page and open **Edit Page** in Lightning App Builder.
2. Drag **timelineHistoryViewer** onto the layout.
3. Save and activate the page.

### 4. Configure child objects

1. On a record page with the component, click the gear icon (visible to admins only).
2. Click **Add Child Object** and select a related object from the dropdown.
3. The child object's field history will appear in the timeline immediately.

## Prerequisites

- Salesforce CLI (`sf`)
- Field history tracking enabled on the objects you want to display
