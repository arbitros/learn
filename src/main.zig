const glfw = @import("glfw");
const std = @import("std");
const gl = @import("gl");
const zlm = @import("zig_matrix");
const shader = @import("shader.zig");
const camera = @import("camera.zig");
const math = std.math;

const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

pub fn main() !void {
    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    try glfw.init();
    defer glfw.terminate();
    std.debug.print("GLFW Init Succeeded.\n", .{});

    const window: ?*glfw.Window = try glfw.createWindow(800, 640, "Hello World", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);

    // Load all OpenGL function pointers
    // ---------------------------------------
    var procs: gl.ProcTable = undefined;

    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;

    // Make the procedure table current on the calling thread.
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);
    glfw.makeContextCurrent(window);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const shaderProgram = try shader.ShaderProgram().init(
        allocator,
        "src/shaders/vshader.glsl",
        "src/shaders/fshader.glsl",
    );
    defer shaderProgram.deinit();

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
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

    const indices = [6 * 6]u32{
        0, 1, 2, 2, 3, 0, // Back face (facing -Z)
        4, 5, 6, 6, 7, 4, // Front face (facing +Z)
        7, 3, 0, 0, 4, 7, // Left face (facing -X)
        5, 1, 2, 2, 6, 5, // Right face (facing +X)
        0, 1, 5, 5, 4, 0, // Bottom face (facing -Y)
        3, 2, 6, 6, 7, 3, // Top face (facing +Y)
    };

    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;
    var EBO: c_uint = undefined;

    gl.GenVertexArrays(1, @ptrCast(&VAO));
    defer gl.DeleteVertexArrays(1, @ptrCast(&VAO));

    gl.GenBuffers(1, @ptrCast(&VBO));
    defer gl.DeleteBuffers(1, @ptrCast(&VBO));

    gl.GenBuffers(1, @ptrCast(&EBO));
    defer gl.DeleteBuffers(1, @ptrCast(&EBO));

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.BindVertexArray(VAO);

    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices.len, &indices, gl.STATIC_DRAW);

    // Specify and link our vertext attribute description
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    glfw.swapInterval(1); //V-sync

    while (!glfw.windowShouldClose(window)) {
        processInput(window);

        gl.ClearColor(0.35, 0.4, 0.95, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // Activate shaderProgram
        gl.UseProgram(shaderProgram.shaderProgram);
        gl.BindVertexArray(VAO); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keep things a bit more organized
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

fn framebuffer_size_callback(window: glfw.Window, width: u32, height: u32) void {
    _ = window;
    gl.Viewport(0, 0, @as(c_int, @intCast(width)), @as(c_int, @intCast(height)));
}

fn processInput(window: ?*glfw.Window) void {
    if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
        glfw.setWindowShouldClose(window, true);
    }
}
