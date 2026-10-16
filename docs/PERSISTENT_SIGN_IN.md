# Remembered sign-in and the top EcoTag label

## Behavior

- Admins and Inspection Team sign in once on a device. Only their session token
  is persisted, not their password, username, role, college, or guest information.
- Startup validates the saved token through the existing `app_session_status`
  RPC before opening a dashboard. Role, name, and assignment come from that fresh
  response. Super Admin opens `/super-admin`; other staff open `/dashboard`.
- First-time visitors still see the public landing page. An expired, revoked,
  disabled, archived, or invalid account/session returns to staff sign-in.
- Temporary network failures show Retry rather than deleting a potentially valid
  token or opening an unverified dashboard. The user can explicitly forget the
  token and sign in manually.
- Logout first deletes the token from device storage, then attempts server
  revocation. If device deletion fails, logout shows an error instead of claiming
  success. If the server is offline after deletion, the app remains signed out;
  the old server session remains valid only until its existing expiry.
- The existing database issues **12-hour sessions**. This update does not extend
  that limit and needs no new SQL migration. An already-issued session must be
  signed into once after installing this update before it can be remembered.
- Guests remain anonymous visits; names and ages are not added to remembered
  sign-in storage.

## Device storage

`flutter_secure_storage` stores the token with platform-provided protection.
Android backups are disabled so device-bound encryption keys are not restored
onto another device. Android minimum API is at least 23. iOS uses this-device-only
Keychain accessibility; macOS uses its non-shared legacy Keychain.

Web storage requires **HTTPS or localhost** and the same browser profile/origin.
A different port or private-browsing session is a different storage context.
Use a stable development address when testing reloads (for example, run
`flutter run -d web-server --web-port 8080` and open `http://localhost:8080` in your
normal browser). Production must use HTTPS and appropriate browser security
headers. No browser storage protects a token from malicious JavaScript executing
in the app's own origin.

Platform setup follows the [secure-storage package documentation](https://pub.dev/packages/flutter_secure_storage).

## EcoTag details

Plant Details displays the existing EcoTag QR payload and selectable/copyable
code at the top, including the public guest profile. The photo widget, sizing,
and placement within the remaining details layout are unchanged. Missing labels
show “No EcoTag assigned”; the app does not generate a replacement code here.
The staff query uses `qr_tag!plant_qr_tag_id_fkey` and the explicit managing-campus
foreign key, avoiding ambiguous relationship embeds.

## Verify on a phone/browser after rebuilding

1. Sign in, close the app fully, and reopen within the session's lifetime.
   Verify the correct role dashboard opens without login.
2. Log out, close, and reopen: the app must not sign back in.
3. Revoke or deactivate the session/account through normal administrator tools;
   reopening must return to sign-in. Do not edit live timestamps solely to test.
4. With an existing saved token, reopen offline: see Retry, not an unverified
   dashboard. Reconnect and retry; the valid session should restore.
5. Check the code above the photo, copy it, and scan the displayed QR. It must
   match the existing physical EcoTag, including after a label replacement.

Automated tests cover the session manager with an injected token store/backend,
startup routing, transient errors, invalid accounts, logout races, and narrow/wide
QR rendering. Real native secure-storage persistence still needs device testing.
