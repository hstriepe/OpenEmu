# OpenEMU Minimal UPdate

Update macOS target version to 12.0 for all modules and both workspaces
Use Xconfig to set up signing with my hstriepe@mac.com account [D6WY385Q4D]

Testcompile using the OpenEmu-metal

When successful, do a release build and export into ./release
Place the cores into ./release/cores
PLease framework into ./release/Frameworks

You may use all bash commands without review. Continue until done.

Pushed to fork.

I have moved the plugins into the standard location. But OpenEu cannot find any.

The OpenEmu app support folder is on /Volumes/Shared/OpenEmu linked via symbolic link from the standard location
The standard distro works. It finds the new plugins and they run both as ARM and Intel.

Just to be clear, the plugins are fine. COuld it be the newer version of Swift caused a change in behavior?

## Resolution

**Root Cause:** Swift 6's `Bundle.principalClass` returns nil for bundled system plugins, causing a crash when AppDelegate tries to access `plugin.controller` (implicitly unwrapped optional).

**Fix Applied:**
1. Added `_controllerLoadAttempted` flag to prevent repeated load attempts
2. Added `hasValidController` property to safely check if a plugin's controller loaded
3. Updated `AppDelegate.loadPlugins()` to skip plugins without valid controllers

This allows the app to gracefully handle bundled plugins that can't load their controllers while still processing plugins from Application Support correctly.
