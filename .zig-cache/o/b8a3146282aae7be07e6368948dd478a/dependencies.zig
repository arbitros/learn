pub const packages = struct {
    pub const @"zglfw-0.1.0-BghZXYzSAAAC5BEWvJEfbYh0wghl9ePUIbB2wr8seqoE" = struct {
        pub const build_root = "/home/dawsl/.cache/zig/p/zglfw-0.1.0-BghZXYzSAAAC5BEWvJEfbYh0wghl9ePUIbB2wr8seqoE";
        pub const build_zig = @import("zglfw-0.1.0-BghZXYzSAAAC5BEWvJEfbYh0wghl9ePUIbB2wr8seqoE");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"zigglgen-0.4.0-bmyqLQ3sLQCP7RyluOjtnnbkbL56JCNeIYDu6odBTQCv" = struct {
        pub const build_root = "/home/dawsl/.cache/zig/p/zigglgen-0.4.0-bmyqLQ3sLQCP7RyluOjtnnbkbL56JCNeIYDu6odBTQCv";
        pub const build_zig = @import("zigglgen-0.4.0-bmyqLQ3sLQCP7RyluOjtnnbkbL56JCNeIYDu6odBTQCv");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zigglgen", "zigglgen-0.4.0-bmyqLQ3sLQCP7RyluOjtnnbkbL56JCNeIYDu6odBTQCv" },
    .{ "zglfw", "zglfw-0.1.0-BghZXYzSAAAC5BEWvJEfbYh0wghl9ePUIbB2wr8seqoE" },
};
