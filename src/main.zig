const build_options = @import("build_options");
const headless_demo = @import("demo/headless_demo.zig");
const window_demo = @import("demo/window_demo.zig");

pub fn main() !void {
    if (build_options.window_demo) {
        return window_demo.run();
    }

    return headless_demo.run();
}
