# EcoTag system diagrams

These diagrams summarize the current Flutter client, Supabase services, user
scopes, and inspection workflow. They are maintained as Mermaid source so they
can be viewed in GitHub and other Mermaid-compatible Markdown viewers.

## System architecture

```mermaid
flowchart LR
    people["Staff and guests"]
    subgraph device["User device"]
        flutter["EcoTag Flutter app<br/>Screens, widgets, models"]
        services["App services<br/>Sessions, data, QR, reports, sync"]
        secure[("Platform-secure storage<br/>Session token, drafts, outbox")]
        camera["Camera and QR scanner"]
        reports["PDF and CSV export"]
        flutter --> services
        services <--> secure
        flutter --> camera
        services --> reports
    end

    subgraph supabase["Supabase project"]
        rpc["Database functions / RPCs<br/>Session, role, scope, and workflow checks"]
        db[("Database<br/>Plants, QR tags, inspections,<br/>accounts, reference data")]
        storage[("Storage<br/>plant-images bucket")]
        rpc <--> db
    end

    people --> flutter
    services <--> rpc
    services <--> db
    services <--> storage
```

The mobile/web client is not the authorization boundary: database functions
validate active staff sessions, role, and assignment scope. Guest access uses
separate public read-only workflows. Device storage holds account-specific
inspection work for later synchronization; it is not a replacement for the
server record.

## Roles and system capabilities

```mermaid
flowchart TB
    super["Super Admin"]
    university["University Admin"]
    campus["Campus Admin"]
    college["College Admin"]
    team["Inspection Team"]
    guest["Guest"]

    accounts["Administrator accounts"]
    universityData["University-wide monitoring and reports"]
    campusData["Assigned-campus monitoring and reports"]
    collegeData["Assigned-college plants, QR tags, schedules,<br/>archives, and Inspection Team accounts"]
    field["Assigned-college plant registration<br/>and inspections, including offline drafts"]
    public["Public read-only QR plant profiles"]

    super --> accounts
    super --> universityData
    university --> universityData
    campus --> campusData
    college --> collegeData
    college --> field
    team --> field
    guest --> public
```

Staff access is restricted to the university, campus, or college scope assigned
to the account. The server rechecks that scope for protected operations.

## Inspection and offline synchronization

```mermaid
flowchart TD
    start([Inspection Team member signs in online])
    download["Download assigned plants and inspection choices"]
    cached[("Account-specific secure device cache")]
    field["Record observation, health/growth, and photos"]
    draft{"Save unfinished draft<br/>or review and submit?"}
    saved["Save draft locally"]
    ready["Create reviewed pending submission<br/>with stable request ID"]
    online{"Network available?"}
    queued["Keep in outbox for retry"]
    check["Server checks session, assignment,<br/>plant locks, and newer observations"]
    photo{"Photo to upload?"}
    upload["Upload photo to plant-images"]
    submit["Submit inspection to server"]
    success["Remove local pending item<br/>and refresh reminders"]
    failure["Keep pending item after failure"]
    retry["Reconnect and retry upload"]

    start --> download --> cached --> field --> draft
    draft -->|Unfinished| saved --> cached
    draft -->|Review and save| ready --> online
    online -->|No| queued --> cached
    online -->|Yes| check --> photo
    photo -->|Yes| upload --> submit
    photo -->|No| submit
    submit -->|Accepted| success
    submit -->|Rejected or network error| failure --> cached
    queued --> retry --> check
```

Offline work is available only after an online sign-in and while the signed-in
session is established. Unreviewed drafts are not uploaded. Failed pending
submissions remain on the device for retry; the server validates them again
when they reconnect.
