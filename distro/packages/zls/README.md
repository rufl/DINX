# ZLS

This package installs the official x86_64 Linux ZLS 0.16.0 release and its
matching Zig 0.16.0 standard library. Both archive URLs and SHA-256 values are
checked in `source.env`.

ZLS is bundled in the base DINX ISO. `/etc/zls.json` is the default global
configuration path and `/etc/xdg/zls.json` is provided as an XDG-compatible
hard link. Both point it at a compact metadata-only Zig shim plus the bundled
standard library, so Zig completion and navigation work without installing a
full compiler or systemd. If the optional Artix `zig` package is installed
later, the shim delegates to that compiler for build and formatting commands.
