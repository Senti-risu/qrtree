# Location options

## Registration

Town and Barangay use existing database options only. Their Add actions and the
new-town ZIP dialog have been removed. Select a town first; Barangay options are
filtered to that town, and ZIP code fills from the selected town. Changing Town
clears the previous Barangay selection.

## Create Admin Account

Campus also uses existing database options only. There is no Add action.
Typing searches the existing options; it does not create or select a new campus.
Choose an existing available campus before creating the account. Existing active
Campus Admin limits and college/campus relationships remain enforced.

Editing a selected name clears the selected ID until an existing option is
selected again. Missing locations must be maintained through your trusted
database administration process.

## Existing database and migration history

No campuses, towns, barangays, accounts, plant records or saved drafts are
deleted by removing these Add actions.

The existing migrations, including
`202610180004_creatable_location_lookups.sql` and
`202610190001_campus_only_lookup_creation.sql`, remain as history. The current
app does not call `app_add_lookup`. An already-deployed RPC is not deleted or
revoked by a client-only update. No live database changes were made by the coding
agent. Do not delete or rewrite an applied migration to remove an app button.
