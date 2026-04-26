const std = @import("std");
const DrawList = @import("../core/draw_list.zig").DrawList;
const FontRegistry = @import("../font/registry.zig").FontRegistry;
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

    pub fn syncFonts(self: *GpuBackend, font_registry: *FontRegistry, cmd: *sdl.SDL_GPUCommandBuffer) !void {
        _ = self;
        _ = font_registry;
        _ = cmd;
        return error.GpuBackendNotImplemented;
    }

    pub fn render(self: *GpuBackend, draw_list: DrawList, cmd: *sdl.SDL_GPUCommandBuffer, target: RenderTarget, opts: RenderOptions) !void {
        _ = self;
        _ = draw_list;
        _ = cmd;
        _ = target;
        _ = opts;
        return error.GpuBackendNotImplemented;
    }
};

test "GpuBackend methods report not implemented" {
    var backend = GpuBackend{
        .allocator = std.testing.allocator,
        .device = undefined,
    };

    var registry = FontRegistry.init(std.testing.allocator);
    defer registry.deinit();

    _ = try registry.addTtf("body", .{
        .ttf_bytes = "fake-font-bytes",
        .base_px = 16,
        .dynamic_glyphs = false,
    });

    const cmd: *sdl.SDL_GPUCommandBuffer = undefined;

    try std.testing.expectError(error.GpuBackendNotImplemented, backend.syncFonts(&registry, cmd));
    try std.testing.expectError(
        error.GpuBackendNotImplemented,
        backend.render(.{ .ops = &.{}, .stats = .{} }, cmd, .{ .width = 960, .height = 540 }, .{}),
    );
}
