# Remember staff sign-ins for 30 days

Run `migrations/202610170002_thirty_day_staff_sessions.sql` in the Supabase SQL
Editor for the project used by your app. The agent has not applied this script
to the live database. It changes new staff sessions from 12 hours to 30 days.
It requires the existing secure-session/production-readiness migrations.

The script preserves the login RPC arguments/result columns, password checking,
failed-attempt lockout, audit logging and inactive-account behavior. Passwords
are not stored on the phone. The session token still uses secure device storage.
Logout, expiry and disabled/archived/deleted-account checks remain enforced.

Existing tokens keep their current expiry. No expired or revoked token is
revived. After installing the migration, log out and sign in once to receive a
new 30-day token. Then close the app using Home/recent apps, not Log out, and
reopen it. The updated app should validate the saved token and open its dashboard.
Always log out on shared or borrowed devices.

Verify that the new login function is installed (without exposing any token):

```sql
select position('30 days' in pg_get_functiondef(
  'public.login_user(text,text)'::regprocedure
)) > 0 as uses_30_day_sessions;
```

Expected result: `true`. New sessions expire 30 days after sign-in, not 30 days
after each app opening. Session length is not automatically renewed indefinitely.

This does not fix an immediate restore/storage failure or an older installed
APK. If closing and immediately reopening still returns to login, investigate
saved-token storage, app version and the session-status response separately.

Local tests compare the new function against the previous secure login function
to ensure only duration and audit duration metadata changed. Live session expiry
must still be checked in your Supabase project after applying the script.
