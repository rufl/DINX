# ZLS

This package installs the official x86_64 Linux ZLS 0.16.0 release and its
matching Zig 0.16.0 standard library. Both archive URLs and SHA-256 values are
checked in `source.env`.

ZLS is published as an optional DINX package, outside the base ISO. `/etc/zls.json` is the default global
configuration path and `/etc/xdg/zls.json` is provided as an XDG-compatible
hard link. Both point it at a compact metadata-only Zig shim plus the bundled
standard library, so Zig completion and navigation work without installing the
Pori and other DINX-native Zig packages that use Zig 0.17.0; this 0.16.0 payload
is only the ZLS/LSP compatibility runtime. If the optional Artix `zig` package is
installed later, the shim delegates to that compiler for build and formatting
commands.
