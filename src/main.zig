const glfw = @import("glfw");
const std = @import("std");
const gl = @import("gl");

const vertexShaderSource =
    \\ #version 410 core
    \\ layout (location = 0) in vec3 aPos;
    \\ void main()
    \\ {
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\ }
;

const fragmentShaderSource =
    \\ #version 410 core
    \\ out vec4 FragColor;
    \\ void main() {
    \\  FragColor = vec4(0.9, 0.2, 0.0, 1.0);   
    \\ }
;

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

    // Create vertex shader
    var vertexShader: c_uint = undefined;
    vertexShader = gl.CreateShader(gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertexShader);

    // Attach the shader source to the vertex shader object and compile it
    gl.ShaderSource(vertexShader, 1, @ptrCast(&vertexShaderSource), null);
    gl.CompileShader(vertexShader);

    // Check if vertex shader was compiled successfully

    var success: c_int = undefined;
    var infoLog: [512]u8 = [_]u8{0} ** 512;

    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);

    if (success == 0) {
        gl.GetShaderInfoLog(vertexShader, 512, null, &infoLog);
        std.log.err("{s}", .{infoLog});
    }

    // Fragment shader
    var fragmentShader: c_uint = undefined;
    fragmentShader = gl.CreateShader(gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragmentShader);

    gl.ShaderSource(fragmentShader, 1, @ptrCast(&fragmentShaderSource), null);
    gl.CompileShader(fragmentShader);

    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);

    if (success == 0) {
        gl.GetShaderInfoLog(fragmentShader, 512, null, &infoLog);
        std.log.err("{s}", .{infoLog});
    }

    // create a program object
    var shaderProgram: c_uint = undefined;
    shaderProgram = gl.CreateProgram();
    std.debug.print("{any}", .{shaderProgram});
    defer gl.DeleteProgram(shaderProgram);

    // attach compiled shader objects to the program object and link
    gl.AttachShader(shaderProgram, vertexShader);
    gl.AttachShader(shaderProgram, fragmentShader);
    gl.LinkProgram(shaderProgram);

    // check if shader linking was successfull
    gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.GetProgramInfoLog(shaderProgram, 512, null, &infoLog);
        std.log.err("{s}", .{infoLog});
    }

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

    // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind

    // You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
    // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.

    glfw.swapInterval(1); //V-sync

    while (!glfw.windowShouldClose(window)) {
        processInput(window);

        gl.ClearColor(0.35, 0.4, 0.95, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // Activate shaderProgram
        gl.UseProgram(shaderProgram);
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
