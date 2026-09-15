# ABR Shortcut

Small macOS launchers for Admin By Request:

- **Enable Admin** clicks through the known request prompts, enters `Update/install applications`, and minimizes the session timer.
- **Stop Admin** clicks **Finish → Yes** to end the session.

## Build and use

Requires macOS and Admin By Request. No third-party build dependencies.

```sh
./build.sh
```

Move the apps from `build/` to a stable location such as `~/Applications`, then drag them into the Dock for one-click use. Allow each app to control System Events when prompted, and enable it under **System Settings → Privacy & Security → Accessibility**.

Edit `requestReason` in `enable-admin.applescript` to change the default reason, then rebuild.

## Status

Prototype targeting the English Admin By Request 5.3.4 dialogs on this Mac, including its exact BITS approval notice. Other versions or organization prompts may need script changes. Authentication and IT approval remain handled by Admin By Request.

Both scripts compile and the individual UI actions were checked. The packaged launchers still need an end-to-end test with Accessibility permission enabled.
