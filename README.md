# ABR Shortcut

A tiny Swift menu-bar app for Admin By Request on macOS. The person menu icon is outlined when inactive and filled when admin is enabled. Its action switches between **Enable Admin** and **Stop Admin** as the session changes.

- Enable fills `Update/install applications`, confirms the known prompts, and minimizes the timer.
- Stop confirms **Finish → Yes**. No extra confirmation in the wrapper.
- Status refreshes every half-second, including sessions changed in ABR itself.

## Build and run

Requires macOS, Xcode Command Line Tools, and Admin By Request.

```sh
./build.sh
```

Builds use the local Keychain certificate `ABR Shortcut Local Development`. Set `SIGNING_IDENTITY` to use another code-signing certificate. Keep the same certificate across updates so Accessibility continues to recognize the app. The signing key stays in Keychain and is not part of this repo. For local development, create a self-signed Code Signing identity in Keychain Access (Certificate Assistant → Create a Certificate), or use an existing Apple development identity. Keep access to its private key restricted. Replacing or renewing the certificate needs a new Accessibility grant.

For a temporary ad-hoc build, use `SIGNING_IDENTITY=- ./build.sh`. Each changed ad-hoc build needs a fresh Accessibility grant.

Move `build/ABR Shortcut.app` to `~/Applications` and open it. Choose **Allow Accessibility…** from its menu and enable **ABR Shortcut** in System Settings once. If upgrading from an ad-hoc build, remove the old Accessibility entry and add the installed app once. An enabled toggle for an old signature does not authorize the new build.

ABR Shortcut runs alongside ABR and depends on it for privileges, policy, authentication, and auditing. Quitting the shortcut does not end an admin session. It does not uninstall or disable ABR.

## Scope

Targets the English ABR 5.3.4 dialogs on this Mac, including the exact BITS approval notice. Unknown prompts and authentication need attention in ABR. Status comes from ABR's accessible menu; unavailable Accessibility access is reported as unknown.

The Swift app has no third-party dependencies.

## Verify the flow

Build with `VERIFY_CYCLE=1 ./build.sh` and install that test build. With no active admin session, quit the shortcut and run:

```sh
open --stdout /tmp/abr-verify.log --stderr /tmp/abr-verify.log \
  ~/Applications/"ABR Shortcut.app" --args --verify-cycle
```

This opt-in test starts a real session, checks that its timer is minimized, stops it, and exits. It refuses an already-active session. Read `/tmp/abr-verify.log` for `VERIFY PASSED` or the failure; reopen the app normally afterward. Normal runs also log status changes to the macOS console. The verification flag is disabled in normal builds; rebuild with `./build.sh` after testing.
