const std = @import("std");
const DrawList = @import("../core/draw_list.zig").DrawList;
const Font = @import("../font/font.zig").Font;
const RenderOptions = @import("common.zig").RenderOptions;
const sdl = @import("sdl_shared.zig");

pub const RenderTarget = struct {
    width: u32,
    height: u32,
};

pub const GpuBackend = struct {
    allocator: std.mem.Allocator,
    device: *sdl.SDL_GPUDevice,

    pub fn init(allocator: std.mem.Allocator, device: *sdl.SDL_GPUDevice, opts: struct {}) !GpuBackend {
        _ = opts;
        return .{ .allocator = allocator, .device = device };
    }

    pub fn deinit(self: *GpuBackend) void {
        _ = self;
    }

    pub fn syncFont(self: *GpuBackend, font: *Font, cmd: *sdl.SDL_GPUCommandBuffer) !void {
        _ = self;
        _ = font;
        _ = cmd;
    }

    pub fn render(self: *GpuBackend, draw_list: DrawList, cmd: *sdl.SDL_GPUCommandBuffer, target: RenderTarget, opts: RenderOptions) !void {
        _ = self;
        _ = draw_list;
        _ = cmd;
        _ = target;
        _ = opts;
    }
};
