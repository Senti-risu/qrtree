# Registration drafts

Use **Save draft on device** at the top of registration. When navigating away,
choose **Save draft**, **Discard**, or **Stay**. Reopen registration with the same
account, assignment and QR context to resume. Review starts at the first step.
Lookup selections are checked against current database choices; managing campus
and college always come from the current account, never from draft contents.

Drafts include form details and the selected photo (existing 6 MB limit), stored
using the app's secure device storage. They do not sync to another device, and
clearing app/browser data or uninstalling can remove them. Web storage is tied
to the browser/site. A failed save keeps you on the form. Saving is explicit,
not automatic: save before force-closing the app. Each account/assignment/QR
context has one draft; saving replaces its previous draft. Signing out does not
delete it, but another account is not offered it.

Successful registration clears the draft; a completed marker protects against
failed cleanup. If device storage completely fails after server registration,
the app warns that the old draft must be discarded. Never submit it again.

## Missing scientific names

After selecting a plant type, type the common name directly. Scientific Name is
editable when the matching classification has no saved name; an existing
scientific name autofills and stays read-only. The common name is required and
accepts up to 100 printable characters. Scientific names remain optional,
accept up to 200 printable characters, and preserve capitalization. Typed names
are kept in a device draft.

A newly entered scientific name is submitted with the registration in one
database call. A new common name is created as a shared classification in that
same transaction. Apply
`supabase/migrations/202610200001_registration_scientific_name.sql` and
`supabase/migrations/202610200003_register_new_classifications.sql` before using
these combined saves. Failed registration rolls back a new classification,
scientific-name update, and the new plant/QR; the form retains its text for
retry. No fallback performs a separate write if a required RPC is missing.
Registrations using an existing classification and no new scientific name
continue using the existing registration RPC.

Scientific names belong to the shared plant classification, not a plant-specific
text column. Successfully filling a missing name therefore also makes it available
to other plants and later registrations of the same classification. Concurrent
submissions cannot overwrite an existing name; a conflicting new name asks the
user to reopen registration and review it. Database atomicity and role/scope
enforcement need live acceptance testing after applying the migration.
