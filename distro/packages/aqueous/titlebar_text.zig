// SPDX-FileCopyrightText: © 2026 Seafoam Labs
// SPDX-License-Identifier: GPL-3.0-only

const std = @import("std");
const wlr = @import("wlroots");
const util = @import("util.zig");

const drm_format_argb8888: u32 = 0x34325241;

extern fn dinx_titlebar_render_text(
    title: [*:0]const u8,
    max_width: c_int,
    height: c_int,
    pixels: [*]u32,
    stride: usize,
) c_int;

const TextBuffer = struct {
    base: wlr.Buffer,
    pixels: []u32,
    stride: usize,

    const implementation: wlr.Buffer.Impl = .{
        .destroy = destroy,
        .get_dmabuf = null,
        .get_shm = null,
        .begin_data_ptr_access = beginDataPtrAccess,
        .end_data_ptr_access = endDataPtrAccess,
    };

    fn destroy(buffer: *wlr.Buffer) callconv(.c) void {
        const text_buffer: *TextBuffer = @fieldParentPtr("base", buffer);
        util.gpa.free(text_buffer.pixels);
        util.gpa.destroy(text_buffer);
    }

    fn beginDataPtrAccess(
        buffer: *wlr.Buffer,
        flags: u32,
        data: **anyopaque,
        format: *u32,
        stride: *usize,
    ) callconv(.c) bool {
        if (flags & wlr.Buffer.data_ptr_access_flag.write != 0) return false;
        const text_buffer: *TextBuffer = @fieldParentPtr("base", buffer);
        data.* = @ptrCast(text_buffer.pixels.ptr);
        format.* = drm_format_argb8888;
        stride.* = text_buffer.stride;
        return true;
    }

    fn endDataPtrAccess(_: *wlr.Buffer) callconv(.c) void {}
};

pub const Rendered = struct {
    buffer: *wlr.Buffer,
    width: i32,
    height: i32,
};

/// Rasterize a bounded title into an immutable wlroots data-pointer buffer.
/// The returned buffer's width is the actual rendered width; its stride may
/// remain larger so Pango can ellipsize without a second allocation.
pub fn render(title: [*:0]const u8, max_width: i32, height: i32) error{OutOfMemory}!?Rendered {
    if (max_width <= 0 or height <= 0) return null;
    const width: usize = @intCast(max_width);
    const height_usize: usize = @intCast(height);
    const pixel_count = std.math.mul(usize, width, height_usize) catch return error.OutOfMemory;
    const pixels = try util.gpa.alloc(u32, pixel_count);
    errdefer util.gpa.free(pixels);

    const stride = width * @sizeOf(u32);
    const rendered_width = dinx_titlebar_render_text(title, max_width, height, pixels.ptr, stride);
    if (rendered_width <= 0 or rendered_width > max_width) return null;

    const text_buffer = try util.gpa.create(TextBuffer);
    text_buffer.* = .{
        .base = undefined,
        .pixels = pixels,
        .stride = stride,
    };
    text_buffer.base.init(&TextBuffer.implementation, rendered_width, height);
    return .{
        .buffer = &text_buffer.base,
        .width = rendered_width,
        .height = height,
    };
}
