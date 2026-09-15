# ABR Shortcut

A tiny Swift menu-bar app for Admin By Request on macOS. The shield menu switches between **Enable Admin** and **Stop Admin** as the session changes.

- Enable fills `Update/install applications`, confirms the known prompts, and minimizes the timer.
- Stop confirms **Finish → Yes**. No extra confirmation in the wrapper.
- Status refreshes every half-second, including sessions changed in ABR itself.

## Build and run

Requires macOS, Xcode Command Line Tools, and Admin By Request.

```sh
./build.sh
```

Move `build/ABR Shortcut.app` to `~/Applications` and open it. Choose **Allow Accessibility…** from its menu and enable **ABR Shortcut** in System Settings once. Rebuilt, locally signed apps may need permission granted again.

ABR Shortcut runs alongside ABR and depends on it for privileges, policy, authentication, and auditing. Quitting the shortcut does not end an admin session. It does not uninstall or disable ABR.

## Scope

Targets the English ABR 5.3.4 dialogs on this Mac, including the exact BITS approval notice. Unknown prompts and authentication need attention in ABR. Status comes from ABR's accessible session window; unavailable Accessibility access is reported as unknown.

The Swift app has no third-party dependencies.
