const glfw = @import("glfw");
const std = @import("std");
const gl = @import("gl");
const zlm = @import("zig_matrix");
const shader = @import("shader.zig");

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
    const vertices = [9]f32{ -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0 };
    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;

    gl.GenVertexArrays(1, @ptrCast(&VAO));
    defer gl.DeleteVertexArrays(1, @ptrCast(&VAO));

    gl.GenBuffers(1, @ptrCast(&VBO));
    defer gl.DeleteBuffers(1, @ptrCast(&VBO));

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.BindVertexArray(VAO);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    // Fill our buffer with the vertex data
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    // Specify and link our vertext attribute description
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    glfw.swapInterval(1); //V-sync

    while (!glfw.windowShouldClose(window)) {
        processInput(window);

        gl.ClearColor(0.35, 0.4, 0.95, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // Activate shaderProgram
        gl.UseProgram(shaderProgram.shaderProgram);
        gl.BindVertexArray(VAO); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keep things a bit more organized
        gl.DrawArrays(gl.TRIANGLES, 0, 3);

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
