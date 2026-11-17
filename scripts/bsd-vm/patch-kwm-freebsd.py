#!/usr/bin/env python3
"""FreeBSD port patches for kwm (the river window manager).

Run inside the FreeBSD build VM:  python3 patch-kwm-freebsd.py /root/kwmbuild

kwm wraps every OS primitive in src/posix.zig and routes it through
`std.posix.system`, which resolves to `std.c` because kwm links libc
(build.zig:246 `.link_libc = true`). On a FreeBSD target three things differ
from Linux, and every one is a *type* mismatch rather than a missing syscall --
FreeBSD 15.1 libc provides timerfd_create/timerfd_settime (since 14,
<sys/timerfd.h>) and memfd_create (since 13); both resolve from plain `cc` with
no extra library.

  1. `system.TFD` is `void` on FreeBSD: Zig's std only declares the timerfd
     flag bitfield for Linux, so the `.{ .NONBLOCK = true, .CLOEXEC = true }`
     literals in src/kwm/key_repeat.zig fail to compile. Declared here with the
     FreeBSD bit positions from <sys/timerfd.h> + <sys/fcntl.h>:
     TFD_TIMER_ABSTIME 0x01 (bit 0), TFD_NONBLOCK = O_NONBLOCK 0x0004 (bit 2),
     TFD_CLOEXEC = O_CLOEXEC 0x00100000 (bit 20).
  2. `signalfd` genuinely does not exist on FreeBSD (no <sys/signalfd.h>), so
     it is emulated with a self-pipe fed by sigaction(2) handlers. kwm's poll
     loop reads one `posix.siginfo_t` record per event and uses `.signo`, which
     the emulation reproduces byte for byte.
     One behavioural consequence: a self-pipe only fires if the signal is
     actually delivered, but kwm blocks INT/TERM/QUIT/CHLD with sigprocmask()
     before creating the fd -- on Linux that blocking *is* what routes them to
     signalfd. The emulation therefore installs the handlers first and then
     resets the mask to empty. Nothing else is blocked at that point (kwm's own
     double-fork path already does exactly this SETMASK-with-empty-set reset in
     src/kwm/context.zig), and the disposition for every signal in the set is
     now our handler, so leaving them unblocked cannot terminate kwm early.
  3. `std.c.itimerspec` names its fields `interval`/`value` on FreeBSD; Linux
     spells them `it_interval`/`it_value`. Only the constructing literal in
     key_repeat.zig needs the rename -- the reset site uses mem.zeroes().

`memfd_create` needs no patch: std.posix.memfd_create already handles
`.freebsd` for >= 13, and kwm's flag argument `linux.MFD.CLOEXEC` is 1, which is
also FreeBSD's MFD_CLOEXEC. `std.posix.pipe` is gone in Zig 0.17 (and
std.posix.write/close too), so the pipe comes from an `extern "c" pipe2` and the
handler from `extern "c" write`; the flags value passed to pipe2 is the one kwm
already computes at the signalfd call site, `(1 << @bitOffsetOf(posix.O,
"NONBLOCK")) | (1 << @bitOffsetOf(posix.O, "CLOEXEC"))`, which on FreeBSD equals
the real O_* bit values (both spellings verified by compiling them against the
FreeBSD target).

Every patch is idempotent and keyed on its own marker token.
"""
import os
import sys

W = sys.argv[1] if len(sys.argv) > 1 else "/root/kwmbuild"
KWM = os.path.join(W, "kwm")
applied = []
failed = []


def patch(path, old, new, label, marker):
    if not os.path.exists(path):
        failed.append("%s: absent %s" % (label, path))
        return
    with open(path, encoding="utf-8") as f:
        src = f.read()
    if marker in src:
        applied.append("%s (already)" % label)
        return
    if old not in src:
        failed.append("%s: anchor not found in %s" % (label, path))
        return
    with open(path, "w", encoding="utf-8") as f:
        f.write(src.replace(old, new, 1))
    applied.append(label)


POSIX = os.path.join(KWM, "src", "posix.zig")
KEYREPEAT = os.path.join(KWM, "src", "kwm", "key_repeat.zig")

SHIM = '''// ---- dinx-freebsd: shim -------------------------------------------------
// Zig declares the timerfd flag bitfield only for Linux; on FreeBSD
// `std.c.TFD` is `void`. These are the FreeBSD bit positions, from
// <sys/timerfd.h> + <sys/fcntl.h>.
const dinx_is_freebsd = builtin.target.os.tag == .freebsd;

const DinXTFD = packed struct(c_uint) {
    ABSTIME: bool = false,
    _1: u1 = 0,
    NONBLOCK: bool = false,
    _3: u17 = 0,
    CLOEXEC: bool = false,
    _21: u11 = 0,
};

pub const TFD = if (dinx_is_freebsd) DinXTFD else system.TFD;
pub const TFD_TIMER = if (dinx_is_freebsd) DinXTFD else system.TFD.TIMER;

// signalfd(2) has no FreeBSD equivalent: emulate it with a self-pipe written
// by sigaction handlers. kwm's loop polls the read end and reads one
// posix.siginfo_t per event, which this reproduces exactly. Zig 0.17 dropped
// std.posix.write/pipe, so both come straight from libc.
extern "c" fn pipe2(fds: *[2]posix.fd_t, flags: c_int) c_int;
extern "c" fn write(fd: c_int, buf: [*]const u8, nbytes: usize) isize;

var dinx_signalfd_write: posix.fd_t = -1;

fn dinx_signalfd_handler(sig: posix.SIG) callconv(.c) void {
    if (dinx_signalfd_write < 0) return;
    var info: posix.siginfo_t = mem.zeroes(posix.siginfo_t);
    info.signo = sig;
    // write(2) is async-signal-safe; a short write just drops one event.
    _ = write(dinx_signalfd_write, @ptrCast(mem.asBytes(&info)), @sizeOf(posix.siginfo_t));
}

const SignalfdError = error{
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    SystemResources,
} || posix.UnexpectedError;

fn dinx_signalfd(fd: posix.fd_t, mask: *const posix.sigset_t, flags: u32) SignalfdError!posix.fd_t {
    _ = fd; // signalfd's existing-fd argument is meaningless for a fresh pipe
    var fds: [2]posix.fd_t = undefined;
    // `flags` is O_NONBLOCK|O_CLOEXEC by value on FreeBSD, exactly what the
    // pipe ends need.
    switch (posix.errno(pipe2(&fds, @bitCast(flags)))) {
        .SUCCESS => {},
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        else => |err| return posix.unexpectedErrno(err),
    }
    dinx_signalfd_write = fds[1];

    var act: posix.Sigaction = .{
        .handler = .{ .handler = dinx_signalfd_handler },
        .mask = posix.sigemptyset(),
        .flags = posix.SA.RESTART,
    };
    for ([_]posix.SIG{ .INT, .TERM, .QUIT, .CHLD }) |sig| {
        if (!posix.sigismember(mask, sig)) continue;
        posix.sigaction(sig, &act, null);
    }
    // Unlike signalfd, a self-pipe needs the signal to be delivered: clear the
    // mask kwm set before calling us (handlers are installed for every signal
    // in the set, so nothing can terminate kwm here).
    var empty = posix.sigemptyset();
    posix.sigprocmask(posix.SIG.SETMASK, &empty, null);
    return fds[0];
}

'''

patch(
    POSIX,
    "pub const munmap = posix.munmap;\n",
    "pub const munmap = posix.munmap;\n\n" + SHIM,
    "posix.zig shim block",
    "dinx-freebsd: shim",
)

# signalfd dispatch: keeps the Linux path byte-identical.
patch(
    POSIX,
    "pub const signalfd = posix.signalfd;\n",
    "pub const signalfd = if (dinx_is_freebsd) dinx_signalfd else posix.signalfd; // dinx-freebsd: signalfd dispatch\n",
    "posix.zig signalfd dispatch",
    "dinx-freebsd: signalfd dispatch",
)

patch(
    POSIX,
    "pub fn timerfd_create(clock_id: system.timerfd_clockid_t, flags: system.TFD) TimerFdCreateError!posix.fd_t {",
    "pub fn timerfd_create(clock_id: system.timerfd_clockid_t, flags: TFD) TimerFdCreateError!posix.fd_t { // dinx-freebsd: TFD type",
    "posix.zig timerfd_create signature",
    "dinx-freebsd: TFD type",
)

patch(
    POSIX,
    "    flags: system.TFD.TIMER,\n",
    "    flags: TFD_TIMER,\n",
    "posix.zig timerfd_settime signature",
    "    flags: TFD_TIMER,\n",
)

patch(
    KEYREPEAT,
    """    const itimerspec: posix.system.itimerspec = .{
        .it_value = .{ .sec = 0, .nsec = repeat_info.delay*time.ns_per_ms },
        .it_interval = .{ .sec = 0, .nsec = @divFloor(time.ns_per_s, repeat_info.rate) },
    };""",
    """    // dinx-freebsd: itimerspec fields: FreeBSD std.c names them
    // `value`/`interval`, Linux spells them `it_value`/`it_interval`.
    const itimerspec: posix.system.itimerspec = if (builtin.target.os.tag == .freebsd) .{
        .value = .{ .sec = 0, .nsec = repeat_info.delay*time.ns_per_ms },
        .interval = .{ .sec = 0, .nsec = @divFloor(time.ns_per_s, repeat_info.rate) },
    } else .{
        .it_value = .{ .sec = 0, .nsec = repeat_info.delay*time.ns_per_ms },
        .it_interval = .{ .sec = 0, .nsec = @divFloor(time.ns_per_s, repeat_info.rate) },
    };""",
    "key_repeat.zig itimerspec field names",
    "dinx-freebsd: itimerspec fields",
)

patch(
    KEYREPEAT,
    'const std = @import("std");\n',
    'const std = @import("std");\nconst builtin = @import("builtin"); // dinx-freebsd: os gate\n',
    "key_repeat.zig builtin import",
    "dinx-freebsd: os gate",
)

# Linux-only errno tag: E.LIBBAD is not a member of FreeBSD's enum, so the
# nested switch does not compile there. execve(2) never returns it on
# FreeBSD, so that whole branch collapses back into unexpectedErrno.
patch(
    POSIX,
    """        else => |err| switch (err) {
            .LIBBAD => return error.InvalidExe,
            else => return posix.unexpectedErrno(err),
        },""",
    """        else => |err| {
            if (dinx_is_freebsd) return posix.unexpectedErrno(err); // dinx-freebsd: execve errno
            switch (err) {
                .LIBBAD => return error.InvalidExe,
                else => return posix.unexpectedErrno(err),
            }
        },""",
    "posix.zig execve LIBBAD guard",
    "dinx-freebsd: execve errno",
)

for a in applied:
    print("patched:", a)
for m in failed:
    print("PROBLEM:", m)
sys.exit(1 if failed else 0)
