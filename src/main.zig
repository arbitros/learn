const glfw = @import("glfw");
const std = @import("std");
const gl = @import("gl");
const zlm = @import("zig_matrix");
const shader = @import("shader.zig");
const _camera = @import("camera.zig");
const _chunk = @import("chunk.zig");
const _game = @import("game.zig");
const math = std.math;

const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4x4;

const WindowSize = struct {
    pub const width: u32 = 1600;
    pub const height: u32 = 1000;
};

const CHUNK_SIZE = 8;
const MAX_BLOCKS = math.powi(u32, CHUNK_SIZE, 3);

pub fn main() !void {
    try glfw.init();
    const window: ?*glfw.Window = try glfw.createWindow(WindowSize.width, WindowSize.height, "Hello World", null, null);
    glfw.makeContextCurrent(window);
    glfw.setInputMode(window, glfw.Cursor, glfw.CursorDisabled);

    std.debug.print("GLFW Init Succeeded.\n", .{});

    var procs: gl.ProcTable = undefined;
    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;
    gl.makeProcTableCurrent(&procs);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game = try _game.Game(CHUNK_SIZE, WindowSize.width, WindowSize.height).init(90, Vec3.init(0, 0, 0), Vec3.init(0, 0, 0), window, allocator);
    defer game.deinit();

    const vertices = [5 * 8]f32{
        // Position        // Texture Coords
        -0.5, -0.5, -0.5, 0.0, 0.0, // 0: back-bottom-left
        0.5, -0.5, -0.5, 1.0, 0.0, // 1: back-bottom-right
        0.5, 0.5, -0.5, 1.0, 1.0, // 2: back-top-right
        -0.5, 0.5, -0.5, 0.0, 1.0, // 3: back-top-left
        -0.5, -0.5, 0.5, 0.0, 0.0, // 4: front-bottom-left
        0.5, -0.5, 0.5, 1.0, 0.0, // 5: front-bottom-right
        0.5, 0.5, 0.5, 1.0, 1.0, // 6: front-top-right
        -0.5, 0.5, 0.5, 0.0, 1.0, // 7: front-top-left
    };

    const indices = [6][6]u32{
        .{ 0, 1, 2, 2, 3, 0 }, // Back face (facing -Z)
        .{ 4, 5, 6, 6, 7, 4 }, // Front face (facing +Z)
        .{ 7, 3, 0, 0, 4, 7 }, // Left face (facing -X)
        .{ 5, 1, 2, 2, 6, 5 }, // Right face (facing +X)
        .{ 0, 1, 5, 5, 4, 0 }, // Bottom face (facing -Y)
        .{ 3, 2, 6, 6, 7, 3 }, // Top face (facing +Y)
    };

    var VBO: c_uint = undefined;
    var VAOs: [6]c_uint = undefined;
    var EBOs: [6]c_uint = undefined;

    gl.GenBuffers(1, @ptrCast(&VBO));
    defer gl.DeleteBuffers(1, @ptrCast(&VBO));
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    for (0..6) |i| {
        gl.GenVertexArrays(1, @ptrCast(&VAOs[i]));
        gl.BindVertexArray(VAOs[i]);

        gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(0);

        gl.GenBuffers(1, @ptrCast(&EBOs[i]));
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBOs[i]);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices[i].len, @ptrCast(&indices[i]), gl.STATIC_DRAW);
    }
    defer for (0..6) |i| {
        gl.DeleteVertexArrays(1, @ptrCast(&VAOs[i]));
        gl.DeleteBuffers(1, @ptrCast(&EBOs[i]));
    };

    game.VAOs = VAOs;

    gl.Enable(gl.DEPTH_TEST);

    glfw.swapInterval(1); //V-sync

    while (!glfw.windowShouldClose(game.window)) {
        try game.update();
        game.draw();
    }
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

test {
    _ = @import("matrix_util.zig");
    _ = @import("game.zig");
    _ = @import("glfw");
}
