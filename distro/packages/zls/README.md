# ZLS

This package installs the official x86_64 Linux ZLS 0.16.0 release from the Zig Language Server build archive. The archive URL and SHA-256 are checked in `source.env`.

ZLS is bundled in the base DINX ISO. Nocted uses it automatically for Zig projects; the package keeps its compatible Zig compiler dependency and does not install a systemd service.
