// bsd_compat.zig — drop-in replacement for `const linux = std.os.linux;`
// in Aqueous sources, backed by FreeBSD libc.
//
// Contract matches std.os.linux: syscall wrappers return usize where a
// non-error is the raw result (fd / byte count / 0) and an error is the
// negative Linux errno encoded as usize. errno(r) decodes that back to the
// std.os.linux.E enum, so existing `switch (linux.errno(rc)) { .AGAIN => ... }`
// call sites compile and behave unchanged. FreeBSD errno values are mapped to
// their Linux E equivalents.
const std = @import("std");
const c = std.c;

// This shim provides ONLY the syscall functions (which SIGSYS as raw Linux
// syscalls on FreeBSD). Types, constants and errno() stay std.os.linux at the
// call sites; the wrappers return the same usize convention linux.errno decodes.

pub const E = std.os.linux.E;

// ── Constants (Linux ABI values; source ORs these together) ────────────────

pub const AF = struct {
    pub const UNIX: u32 = c.AF_UNIX;
    pub const LOCAL: u32 = c.AF_LOCAL;
    pub const INET: u32 = c.AF_INET;
    pub const INET6: u32 = c.AF_INET6;
};

pub const SOCK = struct {
    pub const STREAM: u32 = c.SOCK_STREAM;
    pub const DGRAM: u32 = c.SOCK_DGRAM;
    pub const RAW: u32 = c.SOCK_RAW;
    pub const SEQPACKET: u32 = c.SOCK_SEQPACKET;
    // Linux flag bits; socket()/accept4() translate them to fcntl on FreeBSD.
    pub const NONBLOCK: u32 = 0o4000;
    pub const CLOEXEC: u32 = 0o2000000;
};

pub const MSG = struct {
    // FreeBSD has no MSG_NOSIGNAL; sockets get SO_NOSIGPIPE instead.
    pub const NOSIGNAL: i32 = 0;
    pub const DONTWAIT: i32 = c.MSG_DONTWAIT;
    pub const PEEK: i32 = c.MSG_PEEK;
};

pub const SOL = struct {
    pub const SOCKET: i32 = c.SOL_SOCKET;
};

pub const SO = struct {
    // Call sites pass linux.SO.PEERCRED (std.os.linux value); match it exactly
    // so getsockopt() can translate it to FreeBSD getpeereid().
    pub const PEERCRED: i32 = std.os.linux.SO.PEERCRED;
    pub const REUSEADDR: i32 = c.SO_REUSEADDR;
    pub const ERROR: i32 = c.SO_ERROR;
};

pub const socklen_t = c.socklen_t;

/// Linux-layout sockaddr_un (family u16 + path[108]) so Aqueous call sites
/// compile unchanged; bind()/connect() translate to the FreeBSD layout.
pub const sockaddr = struct {
    pub const un = extern struct {
        family: u16 = 1, // AF_UNIX
        path: [108]u8 = [_]u8{0} ** 108,
    };
};

const bsd_sockaddr_un = extern struct {
    sun_len: u8 = 0,
    sun_family: u8 = 1, // AF_UNIX
    sun_path: [104]u8 = [_]u8{0} ** 104,
};

pub const Statx = std.os.linux.Statx;
pub const STATX = std.os.linux.STATX;
pub const AT = std.os.linux.AT;

extern "c" fn getpeereid(fd: c_int, euid: *c.uid_t, egid: *c.gid_t) c_int;

// ── errno mapping ──────────────────────────────────────────────────────────

fn currentErrnoE() E {
    return switch (c._errno().*) {
        c.EAGAIN, c.EWOULDBLOCK => .AGAIN,
        c.EINTR => .INTR,
        c.EPERM => .PERM,
        c.EACCES => .ACCES,
        c.ENOENT => .NOENT,
        c.EEXIST => .EXIST,
        c.EINVAL => .INVAL,
        c.EISDIR => .ISDIR,
        c.ENOTDIR => .NOTDIR,
        c.ENAMETOOLONG => .NAMETOOLONG,
        c.EBADF => .BADF,
        c.ECONNRESET => .CONNRESET,
        c.EPIPE => .PIPE,
        c.ENOSYS => .NOSYS,
        c.EOPNOTSUPP => .OPNOTSUPP,
        c.ETIMEDOUT => .TIMEDOUT,
        c.ECONNREFUSED => .CONNREFUSED,
        c.ENOTSOCK => .NOTSOCK,
        c.ENOTCONN => .NOTCONN,
        c.EISCONN => .ISCONN,
        c.ENOBUFS => .NOBUFS,
        c.ENOMEM => .NOMEM,
        c.EMFILE => .MFILE,
        c.ENFILE => .NFILE,
        c.EADDRINUSE => .ADDRINUSE,
        c.EADDRNOTAVAIL => .ADDRNOTAVAIL,
        c.EAFNOSUPPORT => .AFNOSUPPORT,
        c.EPROTO => .PROTO,
        else => .INVAL,
    };
}

/// Encode a libc result into the std.os.linux usize convention.
fn rcOrErrno(rc: i64) usize {
    if (rc >= 0) return @intCast(rc);
    return @bitCast(-@as(isize, @intFromEnum(currentErrnoE())));
}

/// Decode the std.os.linux usize convention back to the E enum.
pub fn errno(r: usize) E {
    const s: isize = @bitCast(r);
    if (s > -4096 and s < 0) return @enumFromInt(@intCast(-s));
    return .SUCCESS;
}

// ── Syscall wrappers (libc-backed) ─────────────────────────────────────────

fn setFlags(fd: c_int, sock_type: u32) void {
    if (sock_type & SOCK.NONBLOCK != 0) _ = c.fcntl(fd, c.F_SETFL, c.O_NONBLOCK);
    if (sock_type & SOCK.CLOEXEC != 0) _ = c.fcntl(fd, c.F_SETFD, c.FD_CLOEXEC);
    // MSG_NOSIGNAL is unavailable; suppress SIGPIPE on this socket instead.
    const one: c_int = 1;
    _ = c.setsockopt(fd, c.SOL_SOCKET, c.SO_NOSIGPIPE, &one, @sizeOf(c_int));
}

pub fn socket(domain: u32, sock_type: u32, protocol: u32) usize {
    const base: i32 = @intCast(sock_type & 0xF);
    const fd = c.socket(@intCast(domain), base, @intCast(protocol));
    if (fd < 0) return rcOrErrno(-1);
    setFlags(fd, sock_type);
    return @intCast(fd);
}

fn toBsdUn(linux_un: *const sockaddr.un) bsd_sockaddr_un {
    var bsd: bsd_sockaddr_un = .{};
    var n: usize = 0;
    while (n < linux_un.path.len and linux_un.path[n] != 0) : (n += 1) {}
    if (n > bsd.sun_path.len) n = bsd.sun_path.len;
    @memcpy(bsd.sun_path[0..n], linux_un.path[0..n]);
    bsd.sun_family = c.AF_UNIX;
    bsd.sun_len = @intCast(2 + n + 1);
    return bsd;
}

pub fn bind(fd: i32, addr: *const anyopaque, addrlen: socklen_t) usize {
    const un: *const sockaddr.un = @ptrCast(@alignCast(addr));
    if (un.family == c.AF_UNIX) {
        var bsd = toBsdUn(un);
        const rc = c.bind(@intCast(fd), @ptrCast(&bsd), @sizeOf(bsd_sockaddr_un));
        return rcOrErrno(if (rc == 0) 0 else -1);
    }
    const rc = c.bind(@intCast(fd), @ptrCast(@alignCast(addr)), addrlen);
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn connect(fd: i32, addr: *const anyopaque, addrlen: socklen_t) usize {
    const un: *const sockaddr.un = @ptrCast(@alignCast(addr));
    if (un.family == c.AF_UNIX) {
        var bsd = toBsdUn(un);
        const rc = c.connect(@intCast(fd), @ptrCast(&bsd), @sizeOf(bsd_sockaddr_un));
        return rcOrErrno(if (rc == 0) 0 else -1);
    }
    const rc = c.connect(@intCast(fd), @ptrCast(@alignCast(addr)), addrlen);
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn listen(fd: i32, backlog: i32) usize {
    const rc = c.listen(@intCast(fd), backlog);
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn accept4(fd: i32, addr: ?*anyopaque, addrlen: ?*socklen_t, flags: u32) usize {
    const nfd = c.accept(@intCast(fd), @ptrCast(addr), addrlen);
    if (nfd < 0) return rcOrErrno(-1);
    setFlags(nfd, flags);
    return @intCast(nfd);
}

pub fn close(fd: i32) usize {
    const rc = c.close(@intCast(fd));
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn unlink(path: [*:0]const u8) usize {
    const rc = c.unlink(path);
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn chmod(path: [*:0]const u8, mode: u32) usize {
    const rc = c.chmod(path, @intCast(mode));
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn mkdir(path: [*:0]const u8, mode: u32) usize {
    const rc = c.mkdir(path, @intCast(mode));
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn rmdir(path: [*:0]const u8) usize {
    const rc = c.rmdir(path);
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn recvfrom(fd: i32, buf: [*]u8, len: usize, flags: i32, addr: ?*anyopaque, addrlen: ?*socklen_t) usize {
    const rc = c.recvfrom(@intCast(fd), buf, len, @intCast(flags), @ptrCast(addr), addrlen);
    return rcOrErrno(@intCast(rc));
}

pub fn sendto(fd: i32, buf: [*]const u8, len: usize, flags: i32, addr: ?*const anyopaque, addrlen: socklen_t) usize {
    _ = flags; // MSG_NOSIGNAL is a no-op; SO_NOSIGPIPE is set on the socket.
    const rc = c.sendto(@intCast(fd), buf, len, 0, @ptrCast(addr), addrlen);
    return rcOrErrno(@intCast(rc));
}

pub fn getuid() u32 {
    return c.getuid();
}
pub fn getgid() u32 {
    return c.getgid();
}
pub fn geteuid() u32 {
    return c.geteuid();
}
pub fn getegid() u32 {
    return c.getegid();
}

/// SO_PEERCRED is Linux-only; translate to FreeBSD getpeereid().
pub fn getsockopt(fd: i32, level: i32, optname: i32, optval: *anyopaque, optlen: *socklen_t) usize {
    if (optname == SO.PEERCRED) {
        var euid: c.uid_t = undefined;
        var egid: c.gid_t = undefined;
        if (getpeereid(@intCast(fd), &euid, &egid) != 0) return rcOrErrno(-1);
        const cred: *extern struct { pid: i32, uid: u32, gid: u32 } = @ptrCast(@alignCast(optval));
        cred.pid = 0;
        cred.uid = euid;
        cred.gid = egid;
        optlen.* = @sizeOf(@TypeOf(cred.*));
        return 0;
    }
    const rc = c.getsockopt(@intCast(fd), level, optname, optval, optlen);
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn statx(dirfd: i32, path: [*:0]const u8, flags: u32, mask: STATX, buf: *Statx) usize {
    const f = @extern(*const fn (i32, [*:0]const u8, u32, u32, *Statx) callconv(.c) c_int, .{ .name = "statx" });
    const rc = f(dirfd, path, flags, @bitCast(mask), buf);
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn open(path: [*:0]const u8, flags: u32, mode: u32) usize {
    const rc = c.open(path, @intCast(flags), @intCast(mode));
    return rcOrErrno(@intCast(rc));
}

pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    const rc = c.read(@intCast(fd), buf, count);
    return rcOrErrno(@intCast(rc));
}

pub fn readlink(path: [*:0]const u8, buf: [*]u8, bufsiz: usize) usize {
    const rc = c.readlink(path, buf, bufsiz);
    return rcOrErrno(@intCast(rc));
}

pub fn fsync(fd: i32) usize {
    const rc = c.fsync(@intCast(fd));
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn pause() usize {
    const rc = c.pause();
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn getrlimit(resource: i32, rlim: *anyopaque) usize {
    const rc = c.getrlimit(@intCast(resource), @ptrCast(rlim));
    return rcOrErrno(if (rc == 0) 0 else -1);
}

pub fn fcntl(fd: i32, cmd: i32, arg: i64) usize {
    const rc = c.fcntl(@intCast(fd), cmd, arg);
    return rcOrErrno(@intCast(rc));
}
