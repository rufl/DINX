# Seafoam Settings

Seafoam Settings is a small native Zig/GTK4 launcher for the DINX desktop tools that users commonly configure together:

- `dinx-wdisplays` for interactive Wayland output setup; closing the editor exports the current layout into the named Shikane profile;
- `dinx-save-shikane-profile` to save the current layout directly and reload the running Shikane user daemon;
- the Shikane configuration file for deterministic display profiles;
- DinitUI and DINXPanel for services and DINX controls;
- `qt6ct` for Qt appearance;
- the labwc and Shikane user configuration files;
- Dome when the optional Seafoam monitor package is installed.

Actions use fixed argument vectors. The display wrapper launches `wdisplays`, replaces only the DINX-owned `DINX wdisplays` profile in `~/.config/shikane/config.toml`, and reloads Shikane; the app does not interpret arbitrary shell commands or replace the specialist tools.

The package is optional and is not part of the base DINX ISO. `zls` is packaged separately as an optional Zig language server and is consumed by Nocted when installed.
