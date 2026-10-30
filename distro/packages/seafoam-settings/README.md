# Seafoam Settings

Seafoam Settings is a small native Zig/GTK4 launcher for the DINX desktop tools that users commonly configure together:

- `dinx-wdisplays` for interactive Wayland output setup; closing the editor exports the current layout into the named Shikane profile;
- `dinx-save-shikane-profile` to save the current layout directly and reload the running Shikane user daemon;
- the Shikane configuration file for deterministic display profiles;
- DinitUI and DINXPanel for services and DINX controls;
- `qt6ct` for Qt appearance;
- the Aqueous/Pearl session and Shikane user configuration files;
- Dome for resource/process monitoring; it is bundled in the base ISO.

Actions use fixed argument vectors. The display wrapper launches `wdisplays`, replaces only the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml`, and reloads Shikane; the app does not interpret arbitrary shell commands or replace the specialist tools.

The package is part of the base DINX ISO. `zls` is bundled as the Zig language server for Dintor. The package and its dependencies use the dinit-native DINX runtime; they do not install or require systemd.
