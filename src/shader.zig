const gl = @import("gl");
const std = @import("std");
const file = @import("read_file_c.zig");

pub fn ShaderProgram() type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        shaderProgram: c_uint,
        vShader: c_uint,
        fShader: c_uint,

        pub fn init(allocator: std.mem.Allocator, vShaderPath: []const u8, fShaderPath: []const u8) !Self {
            const vShader = try initShader(allocator, gl.VERTEX_SHADER, vShaderPath);
            const fShader = try initShader(allocator, gl.FRAGMENT_SHADER, fShaderPath);

            try shaderInfoLog(vShader);
            try shaderInfoLog(fShader);

            var shaderProgram: c_uint = undefined;
            shaderProgram = gl.CreateProgram();
            gl.AttachShader(shaderProgram, vShader);
            gl.AttachShader(shaderProgram, fShader);
            gl.LinkProgram(shaderProgram);

            try shaderProgramInfoLog(shaderProgram);

            return Self{
                .allocator = allocator,
                .shaderProgram = shaderProgram,
                .vShader = vShader,
                .fShader = fShader,
            };
        }
        pub fn deinit(self: Self) void {
            gl.DeleteProgram(self.shaderProgram);
            gl.DeleteShader(self.vShader);
            gl.DeleteShader(self.fShader);
        }

        fn initShader(allocator: std.mem.Allocator, shaderType: comptime_int, shaderPath: []const u8) !c_uint {
            var shader: c_uint = undefined;
            shader = gl.CreateShader(shaderType);
            const shaderSource = try file.readFile(allocator, shaderPath);
            defer allocator.free(shaderSource);
            gl.ShaderSource(shader, 1, @ptrCast(&shaderSource), null);
            gl.CompileShader(shader);

            try shaderInfoLog(shader);

            return shader;
        }
        fn shaderInfoLog(shader: c_uint) !void {
            var success: c_int = undefined;
            var infoLog: [512]u8 = [_]u8{0} ** 512;

            gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);

            if (success == 0) {
                gl.GetShaderInfoLog(shader, 512, null, &infoLog);
                std.log.err("Error regarding shader of type: {d}\ninfo log: {s}\n", .{ shader, infoLog });
                return error.Shader;
            }
        }

        fn shaderProgramInfoLog(shaderProgram: c_uint) !void {
            var success: c_int = undefined;
            var infoLog: [512]u8 = [_]u8{0} ** 512;

            gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success);
            if (success == 0) {
                gl.GetProgramInfoLog(shaderProgram, 512, null, &infoLog);
                std.log.err("Error regarding shaderProgram of type: {d}\ninfo log: {s}\n", .{ shaderProgram, infoLog });
                return error.ShaderProgram;
            }
        }
    };
}
