// bsd_compat.zig — thin Zig front-end for the Linux->FreeBSD syscall layer.
//
// Drop-in for `const linux = std.os.linux;`. The actual ABI translation
// (Linux flag/errno numbers, sockaddr_un layout, SO_PEERCRED, statx) lives in
// dinxlinux.c, compiled into libdinxcompat.so. These wrappers only adapt Zig
// types and preserve the std.os.linux usize return convention, so call sites
// keep using `linux.errno(rc)`, `linux.AF.*`, `linux.SOCK.*`, `linux.sockaddr`,
// `linux.Statx`, etc. unchanged.
const std = @import("std");
const lx = std.os.linux;

// ---- externs into libdinxcompat.so (dinxlinux.c) --------------------------

extern "c" fn dinx_socket(domain: c_int, sock_type: c_int, protocol: c_int) usize;
extern "c" fn dinx_bind(fd: c_int, addr: *const anyopaque, addrlen: u32) usize;
extern "c" fn dinx_connect(fd: c_int, addr: *const anyopaque, addrlen: u32) usize;
extern "c" fn dinx_listen(fd: c_int, backlog: c_int) usize;
extern "c" fn dinx_accept4(fd: c_int, addr: ?*anyopaque, addrlen: ?*u32, flags: c_int) usize;
extern "c" fn dinx_close(fd: c_int) usize;
extern "c" fn dinx_unlink(path: [*:0]const u8) usize;
extern "c" fn dinx_chmod(path: [*:0]const u8, mode: u32) usize;
extern "c" fn dinx_mkdir(path: [*:0]const u8, mode: u32) usize;
extern "c" fn dinx_rmdir(path: [*:0]const u8) usize;
extern "c" fn dinx_open(path: [*:0]const u8, flags: u32, mode: u32) usize;
extern "c" fn dinx_read(fd: c_int, buf: [*]u8, n: usize) usize;
extern "c" fn dinx_readlink(path: [*:0]const u8, buf: [*]u8, n: usize) usize;
extern "c" fn dinx_fsync(fd: c_int) usize;
extern "c" fn dinx_pause() usize;
extern "c" fn dinx_recvfrom(fd: c_int, buf: [*]u8, len: usize, flags: c_int, addr: ?*anyopaque, addrlen: ?*u32) usize;
extern "c" fn dinx_sendto(fd: c_int, buf: [*]const u8, len: usize, flags: c_int, addr: ?*const anyopaque, addrlen: u32) usize;
extern "c" fn dinx_fcntl(fd: c_int, cmd: c_int, arg: i64) usize;
extern "c" fn dinx_getrlimit(resource: c_int, rlim: *anyopaque) usize;
extern "c" fn dinx_getsockopt(fd: c_int, level: c_int, optname: c_int, optval: *anyopaque, optlen: *u32) usize;
extern "c" fn dinx_statx(dirfd: c_int, path: [*:0]const u8, flags: u32, mask: u32, buf: *anyopaque) usize;

const c_getuid = @extern(*const fn () callconv(.c) u32, .{ .name = "getuid" });
const c_getgid = @extern(*const fn () callconv(.c) u32, .{ .name = "getgid" });
const c_geteuid = @extern(*const fn () callconv(.c) u32, .{ .name = "geteuid" });
const c_getegid = @extern(*const fn () callconv(.c) u32, .{ .name = "getegid" });

// ---- helpers --------------------------------------------------------------

fn asU32(v: anytype) u32 {
    return switch (@typeInfo(@TypeOf(v))) {
        .int, .comptime_int => @intCast(v),
        .@"enum", .enum_literal => @intFromEnum(v),
        .enum_int => |e| @intCast(@as(e.backing_integer, v)),
        .bool => @intFromBool(v),
        .@"struct" => @bitCast(v), // packed flag structs (linux.O, linux.STATX)
        .optional => |o| asU32(o orelse 0),
        else => @compileError("bsd_compat: unsupported integer/flag type " ++ @typeName(@TypeOf(v))),
    };
}

fn asI32(v: anytype) i32 {
    return switch (@typeInfo(@TypeOf(v))) {
        .int, .comptime_int => @intCast(v),
        .@"enum", .enum_literal => @intFromEnum(v),
        .enum_int => |e| @intCast(@as(e.backing_integer, v)),
        .bool => @intFromBool(v),
        .@"struct" => @as(i32, @bitCast(asU32(v))),
        .optional => |o| asI32(o orelse 0),
        else => @compileError("bsd_compat: unsupported integer type " ++ @typeName(@TypeOf(v))),
    };
}

// ---- syscall wrappers -----------------------------------------------------

pub fn socket(domain: anytype, sock_type: anytype, protocol: anytype) usize {
    return dinx_socket(asI32(domain), asI32(sock_type), asI32(protocol));
}

pub fn bind(fd: anytype, addr: *const anyopaque, addrlen: anytype) usize {
    return dinx_bind(asI32(fd), addr, asU32(addrlen));
}

pub fn connect(fd: anytype, addr: *const anyopaque, addrlen: anytype) usize {
    return dinx_connect(asI32(fd), addr, asU32(addrlen));
}

pub fn listen(fd: anytype, backlog: anytype) usize {
    return dinx_listen(asI32(fd), asI32(backlog));
}

pub fn accept4(fd: anytype, addr: ?*anyopaque, addrlen: ?*u32, flags: anytype) usize {
    return dinx_accept4(asI32(fd), addr, addrlen, asI32(flags));
}

pub fn close(fd: anytype) usize {
    return dinx_close(asI32(fd));
}

pub fn unlink(path: [*:0]const u8) usize {
    return dinx_unlink(path);
}

pub fn chmod(path: [*:0]const u8, mode: anytype) usize {
    return dinx_chmod(path, asU32(mode));
}

pub fn mkdir(path: [*:0]const u8, mode: anytype) usize {
    return dinx_mkdir(path, asU32(mode));
}

pub fn rmdir(path: [*:0]const u8) usize {
    return dinx_rmdir(path);
}

pub fn read(fd: anytype, buf: [*]u8, n: anytype) usize {
    return dinx_read(asI32(fd), buf, @intCast(n));
}

pub fn readlink(path: [*:0]const u8, buf: [*]u8, n: anytype) usize {
    return dinx_readlink(path, buf, @intCast(n));
}

pub fn fsync(fd: anytype) usize {
    return dinx_fsync(asI32(fd));
}

pub fn pause() usize {
    return dinx_pause();
}

pub fn recvfrom(fd: anytype, buf: [*]u8, len: anytype, flags: anytype, addr: ?*anyopaque, addrlen: ?*u32) usize {
    return dinx_recvfrom(asI32(fd), buf, @intCast(len), asI32(flags), addr, addrlen);
}

pub fn sendto(fd: anytype, buf: [*]const u8, len: anytype, flags: anytype, addr: ?*const anyopaque, addrlen: anytype) usize {
    return dinx_sendto(asI32(fd), buf, @intCast(len), asI32(flags), addr, asU32(addrlen));
}

pub fn open(path: [*:0]const u8, flags: lx.O, mode: anytype) usize {
    return dinx_open(path, asU32(flags), asU32(mode));
}

pub fn fcntl(fd: anytype, cmd: anytype, arg: anytype) usize {
    return dinx_fcntl(asI32(fd), asI32(cmd), switch (@typeInfo(@TypeOf(arg))) {
        .int => @intCast(arg),
        .pointer => @intFromPtr(arg),
        .optional => |o| if (o.child == .pointer) @intFromPtr(arg orelse null) else @intCast(arg orelse 0),
        else => @compileError("bsd_compat: unsupported fcntl arg"),
    });
}

pub fn getrlimit(resource: anytype, rlim: *anyopaque) usize {
    return dinx_getrlimit(asI32(resource), rlim);
}

pub fn getsockopt(fd: anytype, level: anytype, optname: anytype, optval: *anyopaque, optlen: *u32) usize {
    return dinx_getsockopt(asI32(fd), asI32(level), asI32(optname), optval, optlen);
}

pub fn statx(dirfd: anytype, path: [*:0]const u8, flags: anytype, mask: anytype, buf: *anyopaque) usize {
    return dinx_statx(asI32(dirfd), path, asU32(flags), asU32(mask), buf);
}

pub fn getuid() u32 {
    return c_getuid();
}
pub fn getgid() u32 {
    return c_getgid();
}
pub fn geteuid() u32 {
    return c_geteuid();
}
pub fn getegid() u32 {
    return c_getegid();
}
