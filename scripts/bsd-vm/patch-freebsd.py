#!/usr/bin/env python3
"""FreeBSD port patches for the DINX desktop stack (run inside the build VM).

Upstream Aqueous/Pearl/greetd target Linux. FreeBSD equivalents:
  - linux/input*.h      -> dev/evdev/input*.h (compat shim headers)
  - prctl(PR_SET_PDEATHSIG) -> procctl(P_PID, 0, PROC_PDEATHSIG_CTL, &sig)
  - prctl(PR_SET_CHILD_SUBREAPER) -> procctl(P_PID, 0, PROC_REAP_ACQUIRE, NULL)
Idempotent: each patch is skipped when already applied; missing patterns fail
loudly so upstream drift is noticed instead of silently skipped.
"""
import os
import sys

W = sys.argv[1] if len(sys.argv) > 1 else "/root/build"
applied = []


def patch(path, old, new, marker):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    if marker in src:
        return
    if old not in src:
        sys.exit(f"PATCH PATTERN MISSING in {path}: {old[:70]!r}")
    with open(path, "w", encoding="utf-8") as f:
        f.write(src.replace(old, new))
    applied.append(path)


# 1. Linux compat shim headers for libevdev/translate-c.
shim = "/usr/local/include/linux"
os.makedirs(shim, exist_ok=True)
for name, real in (
    ("input.h", "dev/evdev/input.h"),
    ("input-event-codes.h", "dev/evdev/input-event-codes.h"),
):
    p = os.path.join(shim, name)
    if not os.path.exists(p):
        with open(p, "w") as f:
            f.write(f"/* FreeBSD compat shim */\n#include <{real}>\n")
        applied.append(p)

# glibc-only headers used by wlroots upstream sources.
for rel, real in (
    ("linux/limits.h", "limits.h"),
    ("linux/errno.h", "errno.h"),
):
    p = os.path.join("/usr/local/include", rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if not os.path.exists(p):
        with open(p, "w") as f:
            f.write(f"/* FreeBSD compat shim */\n#include <{real}>\n")
        applied.append(p)

# sys/sysmacros.h: -std=c11 hides __BSD_VISIBLE major/minor; provide fallbacks.
p = "/usr/local/include/sys/sysmacros.h"
os.makedirs(os.path.dirname(p), exist_ok=True)
with open(p, "w") as f:
    f.write("""/* FreeBSD compat shim */
#include <sys/types.h>
#ifndef major
#define major(x) ((int)(((unsigned)(x) >> 8) & 0xfff))
#define minor(x) ((int)((x) & 0xffff00ff))
#endif
""")
applied.append(p)

# 2. Pearl libc.h: prctl wrapper over procctl on FreeBSD.
patch(
    os.path.join(W, "pearl/bindings/c/libc.h"),
    "#include <sys/prctl.h>",
    """#ifdef __FreeBSD__
#include <sys/procctl.h>
#define PR_SET_PDEATHSIG 1
static inline int prctl(int option, unsigned long a2, unsigned long a3,
                        unsigned long a4, unsigned long a5) {
  (void)a3; (void)a4; (void)a5;
  if (option == PR_SET_PDEATHSIG) {
    int sig = (int)a2;
    return procctl(P_PID, 0, PROC_PDEATHSIG_CTL, &sig);
  }
  return 0;
}
#else
#include <sys/prctl.h>
#endif""",
    "PROC_PDEATHSIG_CTL",
)

HELPERS = """
// FreeBSD port: procctl equivalents of Linux prctl.
extern "c" fn procctl(idtype: c_int, id: c_int, cmd: c_int, data: ?*anyopaque) c_int;
fn dinx_pdeathsig(sig: c_int) c_int {
    var s: c_int = sig;
    return procctl(0, 0, 11, &s); // P_PID, PROC_PDEATHSIG_CTL
}
fn dinx_subreaper() c_int {
    return procctl(0, 0, 2, null); // P_PID, PROC_REAP_ACQUIRE
}
"""

# 3. Pearl Zig call sites that use std.os.linux / zig-wayland linux prctl.
patch(
    os.path.join(W, "pearl/src/files/preview/platform/preview_runner.zig"),
    "if (linux.errno(linux.prctl(@intFromEnum(linux.PR.SET_PDEATHSIG), @intFromEnum(c.SIG.KILL), 0, 0, 0)) != .SUCCESS or c.getppid() != parent) c._exit(125);",
    "if (dinx_pdeathsig(@intFromEnum(c.SIG.KILL)) != 0 or c.getppid() != parent) c._exit(125);",
    "dinx_pdeathsig",
)
patch(
    os.path.join(W, "pearl/src/greeter/host.zig"),
    "if (std.os.linux.prctl(36, 1, 0, 0, 0) != 0) return error.Subreaper;",
    "if (dinx_subreaper() != 0) return error.Subreaper;",
    "dinx_subreaper",
)
patch(
    os.path.join(W, "pearl/src/greeter/host.zig"),
    "_ = std.os.linux.prctl(1, @backingInt(std.c.SIG.KILL), 0, 0, 0);",
    "_ = dinx_pdeathsig(@backingInt(std.c.SIG.KILL));",
    "dinx_pdeathsig(@backingInt",
)
for rel in (
    "pearl/src/files/preview/platform/preview_runner.zig",
    "pearl/src/greeter/host.zig",
):
    p = os.path.join(W, rel)
    with open(p, "r", encoding="utf-8") as f:
        src = f.read()
    if "fn dinx_pdeathsig" not in src:
        with open(p, "a", encoding="utf-8") as f:
            f.write(HELPERS)
        applied.append(p + " (helpers)")

# 4. greetd: libc::prctl -> libc::procctl on FreeBSD.
patch(
    os.path.join(W, "greetd/greetd/src/session/prctl.rs"),
    "libc::prctl(PRCTL_SET_PDEATHSIG, sig, 0, 0, 0)",
    "{ let mut s = sig; libc::procctl(libc::P_PID, 0, libc::PROC_PDEATHSIG_CTL, &mut s as *mut i32 as *mut libc::c_void) }",
    "PROC_PDEATHSIG_CTL",
)

print("patched:", *applied, sep="\n  ")

# 5. Pearl: link the FreeBSD compat lib (statx/mallopt) into every module.
patch(
    os.path.join(W, "pearl/build.zig"),
    '    m.addImport("pearl_version", pearl_version);\n    return m;',
    '    m.addImport("pearl_version", pearl_version);\n    m.linkSystemLibrary("dinxcompat", .{});\n    return m;',
    'linkSystemLibrary("dinxcompat"',
)

# 6. Aqueous: sd-bus via basu on FreeBSD (no libsystemd).
patch(
    os.path.join(W, "Aqueous/compositor/build.zig"),
    'linkSystemLibrary("libsystemd", .{});',
    'linkSystemLibrary("basu", .{});',
    'linkSystemLibrary("basu"',
)
for name in ("sd-bus.h", "sd-daemon.h"):
    src_h = f"/usr/local/include/basu/{name}"
    dst_h = f"/usr/local/include/systemd/{name}"
    if os.path.exists(src_h) and not os.path.exists(dst_h):
        os.makedirs(os.path.dirname(dst_h), exist_ok=True)
        with open(dst_h, "w") as f:
            f.write(f"/* FreeBSD compat shim */\n#include <basu/{name}>\n")
        applied.append(dst_h)

# 7. Pearl: PTHREAD_ONCE_INIT is a brace macro translate-c cannot emit.
patch(
    os.path.join(W, "pearl/src/theme/repository.zig"),
    "var curl_once: c.pthread_once_t = c.PTHREAD_ONCE_INIT;",
    "var curl_once: c.pthread_once_t = std.mem.zeroes(c.pthread_once_t);",
    "std.mem.zeroes(c.pthread_once_t)",
)

# 8. Aqueous: sd-login.h shim (sd_pidfd_get_user_unit lives in dinxcompat).
p = "/usr/local/include/systemd/sd-login.h"
if not os.path.exists(p):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write("/* FreeBSD compat shim */\n#include <basu/sd-bus.h>\n"
                "int sd_pidfd_get_user_unit(int pidfd, const char *unit, char **ret);\n")
    applied.append(p)

# 9. Aqueous: zig 0.17 FilePermissions.fromMode takes u16.
patch(
    os.path.join(W, "Aqueous/compositor/aqueous/ConfigTransaction.zig"),
    ".permissions = .fromMode(mode)",
    ".permissions = .fromMode(@as(u16, @intCast(mode)))",
    ".fromMode(@as(u16",
)

# 10. Pearl: FreeBSD AT struct has no EMPTY_PATH; use the fcntl.h value.
# Only sys./c. namespaces (std.os.linux.AT.EMPTY_PATH stays valid).
import pathlib
import re
for z in pathlib.Path(os.path.join(W, "pearl/src")).rglob("*.zig"):
    src = z.read_text(encoding="utf-8")
    new = re.sub(r"\b(sys|c)\.AT\.EMPTY_PATH", "0x10000 /* AT_EMPTY_PATH */", src)
    if new != src:
        z.write_text(new, encoding="utf-8")
        applied.append(str(z))

# 11. sd_pidfd_get_user_unit: upstream calls it with 2 args.
patch(
    "/usr/local/include/systemd/sd-login.h",
    "int sd_pidfd_get_user_unit(int pidfd, const char *unit, char **ret);",
    "int sd_pidfd_get_user_unit(int pidfd, char **unit);",
    "char **unit);",
)

# 12. Aqueous activity bootstrap: SO_PEERCRED/SO_PEERPIDFD/pidfd are Linux
# only; disable the feature on FreeBSD instead of faking credentials.
patch(
    os.path.join(W, "Aqueous/compositor/aqueous/activity_bootstrap.c"),
    """    struct ucred cred;
    socklen_t len = sizeof(cred);
    if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &len) < 0 || len != sizeof(cred) || cred.uid != getuid()) { close(fd); return; }
    int pidfd = -1;
    len = sizeof(pidfd);
    if (getsockopt(fd, SOL_SOCKET, SO_PEERPIDFD, &pidfd, &len) < 0 || len != sizeof(pidfd)) { close(fd); return; }
    fcntl(pidfd, F_SETFD, FD_CLOEXEC);
    b->peer = fd;
    b->peer_pidfd = pidfd;
    b->peer_pid = cred.pid;""",
    """#ifdef __FreeBSD__
    /* No SO_PEERCRED/SO_PEERPIDFD/pidfd semantics on FreeBSD: session
     * activity claims are disabled (documented degradation). */
    close(fd); return;
#else
    struct ucred cred;
    socklen_t len = sizeof(cred);
    if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &len) < 0 || len != sizeof(cred) || cred.uid != getuid()) { close(fd); return; }
    int pidfd = -1;
    len = sizeof(pidfd);
    if (getsockopt(fd, SOL_SOCKET, SO_PEERPIDFD, &pidfd, &len) < 0 || len != sizeof(pidfd)) { close(fd); return; }
    fcntl(pidfd, F_SETFD, FD_CLOEXEC);
    b->peer = fd;
    b->peer_pidfd = pidfd;
    b->peer_pid = cred.pid;
#endif""",
    "activity claims are disabled",
)

# 13. Pearl: inline comments mid-expression break Zig lexing; plain literal.
for z in pathlib.Path(os.path.join(W, "pearl/src")).rglob("*.zig"):
    src = z.read_text(encoding="utf-8")
    if "0x10000 /* AT_EMPTY_PATH */" in src:
        z.write_text(src.replace("0x10000 /* AT_EMPTY_PATH */", "0x10000"), encoding="utf-8")
        applied.append(str(z))

# 14. Pearl: FreeBSD siginfo_t exposes `pid` directly (no Linux union).
for z in pathlib.Path(os.path.join(W, "pearl/src")).rglob("*.zig"):
    src = z.read_text(encoding="utf-8")
    new = src.replace("info.fields.common.first.piduid.pid", "info.pid")
    new = new.replace("info.si_pid", "info.pid")
    if new != src:
        z.write_text(new, encoding="utf-8")
        applied.append(str(z))

# 15. Pearl: remaining PTHREAD_ONCE_INIT brace macro (fetch.zig).
patch(
    os.path.join(W, "pearl/src/agent/fetch.zig"),
    "var once: c.pthread_once_t = c.PTHREAD_ONCE_INIT;",
    "var once: c.pthread_once_t = std.mem.zeroes(c.pthread_once_t);",
    "std.mem.zeroes(c.pthread_once_t)",
)

# 16. Pearl: AT_CLKTCK auxval is Linux-only; zig's FreeBSD _SC enum only has
# PAGESIZE, so pass the raw _SC_CLK_TCK value (3, unistd.h).
p = os.path.join(W, "pearl/src/cli/server.zig")
if os.path.exists(p):
    src = open(p, encoding="utf-8").read()
    for old, new in (
        (
            "const hz = @as(usize, @intCast(std.c.sysconf(3 /* _SC_CLK_TCK */)));",
            "const hz = @as(usize, @intCast(std.c.sysconf(3)));",
        ),
        (
            "const hz = std.c.getauxval(std.elf.AT.CLKTCK);",
            "const hz = std.c.sysconf(3);",
        ),
        (
            "const hz = std.c.getauxval(3);",
            "const hz = std.c.sysconf(3);",
        ),
    ):
        if old in src:
            src = src.replace(old, new)
            applied.append(p)
    open(p, "w", encoding="utf-8").write(src)

# 17. Aqueous: link dinxcompat (crt __progname shim) like Pearl does.
patch(
    os.path.join(W, "Aqueous/compositor/build.zig"),
    'river.root_module.linkSystemLibrary("basu", .{});',
    'river.root_module.linkSystemLibrary("basu", .{});\n        river.root_module.linkSystemLibrary("dinxcompat", .{});',
    'linkSystemLibrary("dinxcompat"',
)

# 18. greetd: FreeBSD vt devices are /dev/ttyvN, not /dev/ttyN.
p = os.path.join(W, "greetd/greetd/src/server.rs")
src = open(p, encoding="utf-8").read()
if "/dev/ttyv" not in src:
    src = src.replace('"/dev/tty"', '"/dev/ttyv"')
    src = src.replace('"/dev/tty0"', '"/dev/ttyv0"')
    src = src.replace('format!("/dev/tty{vt}")', 'format!("/dev/ttyv{vt}")')
    open(p, "w", encoding="utf-8").write(src)
    applied.append(p)

# 19. greetd: Linux VT ioctl numbers are hardcoded; on FreeBSD the kernel vt
# and the compositor DRM backend manage VTs, so stub them out.
p = os.path.join(W, "greetd/greetd/src/terminal/ioctl.rs")
src = open(p, encoding="utf-8").read()
old = """ioctl_write_int_bad!(kd_setmode, KDSETMODE);
ioctl_write_int_bad!(vt_activate, VT_ACTIVATE);
ioctl_write_int_bad!(vt_waitactive, VT_WAITACTIVE);
ioctl_write_ptr_bad!(vt_setmode, VT_SETMODE, vt_mode);
ioctl_write_ptr_bad!(vt_setactivate, VT_SETACTIVATE, vt_setactivate);
ioctl_read_bad!(vt_openqry, VT_OPENQRY, i64);
ioctl_read_bad!(vt_getstate, VT_GETSTATE, vt_state);
ioctl_write_int_bad!(term_tiocsctty, TIOCSCTTY);"""
new = """#[cfg(not(target_os = "freebsd"))]
ioctl_write_int_bad!(kd_setmode, KDSETMODE);
#[cfg(not(target_os = "freebsd"))]
ioctl_write_int_bad!(vt_activate, VT_ACTIVATE);
#[cfg(not(target_os = "freebsd"))]
ioctl_write_int_bad!(vt_waitactive, VT_WAITACTIVE);
#[cfg(not(target_os = "freebsd"))]
ioctl_write_ptr_bad!(vt_setmode, VT_SETMODE, vt_mode);
#[cfg(not(target_os = "freebsd"))]
ioctl_write_ptr_bad!(vt_setactivate, VT_SETACTIVATE, vt_setactivate);
#[cfg(not(target_os = "freebsd"))]
ioctl_read_bad!(vt_openqry, VT_OPENQRY, i64);
#[cfg(not(target_os = "freebsd"))]
ioctl_read_bad!(vt_getstate, VT_GETSTATE, vt_state);
#[cfg(not(target_os = "freebsd"))]
ioctl_write_int_bad!(term_tiocsctty, TIOCSCTTY);

#[cfg(target_os = "freebsd")]
pub unsafe fn kd_setmode(_fd: i32, _mode: i32) -> nix::Result<()> { Ok(()) }
#[cfg(target_os = "freebsd")]
pub unsafe fn vt_activate(_fd: i32, _vt: i32) -> nix::Result<()> { Ok(()) }
#[cfg(target_os = "freebsd")]
pub unsafe fn vt_waitactive(_fd: i32, _vt: i32) -> nix::Result<()> { Ok(()) }
#[cfg(target_os = "freebsd")]
pub unsafe fn vt_setmode(_fd: i32, _m: *const vt_mode) -> nix::Result<()> { Ok(()) }
#[cfg(target_os = "freebsd")]
pub unsafe fn vt_setactivate(_fd: i32, _m: *const vt_setactivate) -> nix::Result<()> { Ok(()) }
#[cfg(target_os = "freebsd")]
pub unsafe fn vt_openqry(_fd: i32, _v: *mut i64) -> nix::Result<()> { Ok(()) }
#[cfg(target_os = "freebsd")]
pub unsafe fn vt_getstate(_fd: i32, _s: *mut vt_state) -> nix::Result<()> { Ok(()) }
#[cfg(target_os = "freebsd")]
pub unsafe fn term_tiocsctty(_fd: i32, _arg: i32) -> nix::Result<()> { Ok(()) }"""
if "target_os = \"freebsd\"" not in src:
    if old not in src:
        sys.exit("PATCH PATTERN MISSING in greetd ioctl.rs")
    open(p, "w", encoding="utf-8").write(src.replace(old, new, 1))
    applied.append(p)

# 20. --as-needed drops libdinxcompat (no directly referenced symbols);
# force DT_NEEDED so the crt/__progname shim is actually loaded.
for p, old, new in [
    (os.path.join(W, "Aqueous/compositor/build.zig"),
     'river.root_module.linkSystemLibrary("dinxcompat", .{});',
     'river.root_module.linkSystemLibrary("dinxcompat", .{ .needed = true });'),
    (os.path.join(W, "pearl/build.zig"),
     'm.linkSystemLibrary("dinxcompat", .{});',
     'm.linkSystemLibrary("dinxcompat", .{ .needed = true });'),
]:
    s = open(p, encoding="utf-8").read()
    if old in s:
        open(p, "w", encoding="utf-8").write(s.replace(old, new))
        applied.append(p)

# 21. std.os.linux.statx is a raw Linux syscall; FreeBSD has none. Route it
# through libc statx (provided by libdinxcompat) so every Zig call site works.
import glob
for p in glob.glob(os.path.join(W, "zig-x86_64-freebsd-*", "lib", "std", "os", "linux.zig")):
    src = open(p, encoding="utf-8").read()
    old = """    return syscall5(
        .statx,
        @as(u32, @bitCast(dirfd)),
        @intFromPtr(path),
        flags,
        @as(u32, @bitCast(mask)),
        @intFromPtr(statx_buf),
    );"""
    new = """    // dinx-statx-libc: FreeBSD has no statx syscall; use the libc shim.
    const f = @extern(*const fn (fd_t, [*:0]const u8, u32, u32, *Statx) callconv(.c) c_int, .{ .name = "statx" });
    const rc = f(dirfd, path, flags, @as(u32, @bitCast(mask)), statx_buf);
    if (rc == 0) return 0;
    return @intCast(@import("../c.zig")._errno().*);"""
    if old in src:
        open(p, "w", encoding="utf-8").write(src.replace(old, new))
        applied.append(p)
    elif "dinx-statx-libc" in src:
        lines = src.splitlines(keepends=True)
        i = next(k for k, l in enumerate(lines) if "dinx-statx-libc" in l)
        lines[i + 1 : i + 5] = [l + "\n" for l in new.splitlines()[1:]]
        open(p, "w", encoding="utf-8").write("".join(lines))
        applied.append(p)

# 22. Pearl session validation: accept Weston as the compositor (the BSD
# session uses Weston + Xwayland; Aqueous' Wayland socket is broken on FreeBSD).
p = os.path.join(W, "pearl/src/core/startup.zig")
if os.path.exists(p):
    src = open(p, encoding="utf-8").read()
    old = 'for ([_][]const u8{ "Aqueous", "Aqueous-Git", "Aqueous-Intel-Git" }) |name| {'
    new = 'for ([_][]const u8{ "Aqueous", "Aqueous-Git", "Aqueous-Intel-Git", "Weston" }) |name| {'
    if old in src:
        open(p, "w", encoding="utf-8").write(src.replace(old, new))
        applied.append(p)

# 23. Pearl under Weston: no Aqueous IPC endpoint exists; skip the Aqueous
# identity checks when the session desktop is Weston.
p = os.path.join(W, "pearl/src/core/startup.zig")
if os.path.exists(p):
    src = open(p, encoding="utf-8").read()
    old = "    if (!supported) return error.AqueousSessionRequired;\n"
    new = old + (
        '    if (std.ascii.indexOfIgnoreCase(environment.desktop, "weston") != null) return;\n'
    )
    if old in src and "indexOfIgnoreCase(environment.desktop" not in src:
        open(p, "w", encoding="utf-8").write(src.replace(old, new, 1))
        applied.append(p)

# 24. Aqueous xwayland_dpi.zig: Linux-only errno/environ/self-exe.
#   - c.__errno_location() is glibc; FreeBSD std exposes std.c._errno().
#   - c.environ is not in the translated C module; use std.posix.environ.
#   - /proc/self/exe does not exist; use std.fs.selfExePathAlloc.
p = os.path.join(W, "Aqueous/compositor/aqueous/xwayland_dpi.zig")
if os.path.exists(p):
    src = open(p, encoding="utf-8").read()
    orig = src
    src = src.replace("c.__errno_location().*", "std.c._errno().*")
    if "dinx_self_exe_path" not in src:
        src = src.replace(
            'pub const c = @import("xwayland_c");',
            'pub const c = @import("xwayland_c");\n'
            'extern "c" fn dinx_self_exe_path(buf: [*]u8, size: usize) c_int;\n'
            "// libc's environ (provided by crt1); std.posix does not re-export it.\n"
            "extern \"c\" var environ: [*c]const [*c]u8;",
            1,
        )
    src = src.replace(
        'if (c.posix_spawn(&self.pid, "/proc/self/exe", &actions, &attr, '
        '@ptrCast(@constCast(&argv)), c.environ) != 0) return error.Spawn;',
        "var exe_buf: [4096]u8 = undefined;\n"
        "        if (dinx_self_exe_path(exe_buf[0..].ptr, exe_buf.len) <= 0) return error.Spawn;\n"
        "        if (c.posix_spawn(&self.pid, @ptrCast(&exe_buf), &actions, &attr, "
        "@ptrCast(@constCast(&argv)), environ) != 0) return error.Spawn;",
    )
    if src != orig:
        open(p, "w", encoding="utf-8").write(src)
        applied.append(p)

# 24b. xwayland_dpi.h translate-c chokes on FreeBSD's __SSP_FORTIFY_LEVEL
# fortified inline functions. Disable before the system headers are pulled in.
p = os.path.join(W, "Aqueous/compositor/aqueous/xwayland_dpi.h")
if os.path.exists(p):
    src = open(p, encoding="utf-8").read()
    if "__SSP_FORTIFY_LEVEL" not in src:
        src = src.replace(
            "#define _GNU_SOURCE 1",
            "#define _GNU_SOURCE 1\n#undef __SSP_FORTIFY_LEVEL\n#undef _FORTIFY_SOURCE",
            1,
        )
        open(p, "w", encoding="utf-8").write(src)
        applied.append(p)
