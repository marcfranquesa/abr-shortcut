# Development and operation

## Build and run

Requires macOS, Xcode Command Line Tools, and Admin By Request.

```sh
./build.sh
```

Builds use the local Keychain certificate `ABR Shortcut Local Development`. Set `SIGNING_IDENTITY` to use another code-signing certificate. Keep the same certificate across updates so Accessibility continues to recognize the app. The signing key stays in Keychain and is not part of this repo. For local development, create a self-signed Code Signing identity in Keychain Access (Certificate Assistant → Create a Certificate), or use an existing Apple development identity. Keep access to its private key restricted. Replacing or renewing the certificate needs a new Accessibility grant.

For a temporary ad-hoc build, use `SIGNING_IDENTITY=- ./build.sh`. Each changed ad-hoc build needs a fresh Accessibility grant.

Move `build/ABR Shortcut.app` to `~/Applications` and open it. Click **Enable Admin**. If Accessibility is missing, the app prompts you and opens System Settings; enable **ABR Shortcut** there, then click **Enable Admin** again. If upgrading from an ad-hoc build, remove the old Accessibility entry and add the installed app once. An enabled toggle for an old signature does not authorize the new build.

ABR Shortcut runs alongside ABR and depends on it for privileges, policy, authentication, and auditing. Quitting the shortcut does not end an admin session. It does not uninstall or disable ABR.

## Scope

Targets the English ABR 5.3.4 dialogs on this Mac, including the exact BITS approval notice. Unknown prompts and authentication need attention in ABR. Status comes from ABR's accessible menu; missing Accessibility access is requested when you click **Enable Admin**.

The Swift app has no third-party dependencies.

The workflow polls every 0.1 seconds while enabling or stopping, and every 60 seconds while admin is active, with no polling while inactive. Each check reads the native menu once. Stop completes after one second of observed inactive status; an active or unreadable status restarts that check.

## Verify the flow

Build with `VERIFY_CYCLE=1 ./build.sh` and install that test build. With no active admin session, quit the shortcut using Activity Monitor and run:

```sh
open --stdout /tmp/abr-verify.log --stderr /tmp/abr-verify.log \
  ~/Applications/"ABR Shortcut.app" --args --verify-cycle
```

This opt-in test starts a real session, checks that its timer is minimized, stops it, and exits. It refuses an already-active session. Read `/tmp/abr-verify.log` for `VERIFY PASSED` or the failure; reopen the app normally afterward. Normal runs also log status changes to the macOS console. The verification flag is disabled in normal builds; rebuild with `./build.sh` after testing.

## Status checks

Check once on launch and whenever the menu opens. While admin is off, no timer runs; sessions started directly in ABR are detected on the next manual refresh or launch. Enable and Stop flows check every 100 ms. After enabling, check every 60 seconds for expiry or revocation. Once inactive status is confirmed, invalidate the timer. Failed reads retain monitoring for a previously active session until its end can be confirmed. Stop still requires one second of consistent inactive status before completing.
