const gl = @import("gl");
const std = @import("std");
const file = @import("read_file_c.zig");

pub fn ShaderProgram() type {}

pub fn Shader() type {
    return struct {
        const Self = @This();
        shader: c_int,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, shaderType: comptime_int, shaderPath: []const u8) !Self {
            var shader = undefined;
            shader = gl.CreateShader(shaderType);
            const shaderSource = try file.readFile(allocator, "vertexShader.glsl");
            defer allocator.free(shaderSource);
            errdefer allocator.free(shaderSource);
            gl.ShaderSource(shader, 1, @ptrCast(&shaderSource), null);
            gl.CompileShader(shader);

            try shaderInfoLog();

            return Self{
                .shader = shader,
                .allocator = allocator,
            };
        }
        fn shaderInfoLog(self: Self) !void {
            var success: c_int = undefined;
            var infoLog: [512]u8 = [c_int]u8{0} ** 512;

            gl.GetShaderiv(self.shader, gl.COMPILE_STATUS, &success);

            if (success == 0) {
                gl.GetShaderInfoLog(self.shader, 512, null, &infoLog);
                std.log.err("Error regarding shader of type: {d}\ninfo log: {s}\n", .{ self.shader, infoLog });
                return error.Shader;
            }
        }

        pub fn deinit(self: Self) void {
            gl.DeleteShader(self.shader);
        }
    };
}
