# APK release setup

Analysis and tests must pass before release. Each CI run uses an increasing
Android build number (1000 + workflow run number) and version/build release tag.
Reruns update the same release only when its tag points to the same commit.
Do not reset the workflow counter or distribute local builds with higher codes.

Set repository Actions secrets: KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_PASSWORD,
KEY_ALIAS, SUPABASE_URL, SUPABASE_ANON_KEY. Use your existing release keystore,
backed up securely. Never commit keys or passwords. Missing signing configuration
now fails instead of silently signing with a debug key.

Local release builds require ignored android/key.properties containing
storeFile (relative to android/ or absolute), storePassword, keyAlias, keyPassword.
Java properties escaping applies to Windows paths/passwords. Debug builds do not
need signing configuration.

Android updates require the same application ID and signing certificate and a
higher build number. A previously debug-signed installation will not accept an
update signed with a different release key. Plan a data-safe migration before
changing certificates; uninstalling may erase local sessions and drafts.

The installed version/build appears at the bottom of More. Test install/update,
saved login, logout, camera permission, registration/photo/draft restoration,
scanning, and dead-plant restrictions on a real phone. CI does not verify these
on a physical device. This implementation does not generate keys or set secrets.
