const glfw = @import("glfw");
const std = @import("std");
const gl = @import("gl");
const zlm = @import("zig_matrix");
const shader = @import("shader.zig");
const _camera = @import("camera.zig");
const math = std.math;

const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4x4;

const WindowSize = struct {
    pub const width: u32 = 1600;
    pub const height: u32 = 1000;
};

var lastX: f64 = @as(f64, @floatFromInt(WindowSize.width / 2));
var lastY: f64 = @as(f64, @floatFromInt(WindowSize.height / 2));
var xpos: f64 = 0;
var ypos: f64 = 0;
var firstMouse = true;

pub fn Game() type {
    return struct {
        window: ?*glfw.Window,
        camera: _camera.Camera(),
        deltaTime: f32,
        currentShader: shader.ShaderProgram(),
        VAOs: [6]c_uint,

        const Self = @This();

        pub fn init(FOV: f32, obj: Vec3, objPos: Vec3) anyerror!Self {
            const camera = _camera.Camera().init(FOV, obj, objPos, @as(f32, @floatFromInt(WindowSize.width / WindowSize.height)));

            try glfw.init();
            const window: ?*glfw.Window = try glfw.createWindow(WindowSize.width, WindowSize.height, "Hello World", null, null);
            glfw.makeContextCurrent(window);
            glfw.setInputMode(window, glfw.Cursor, glfw.CursorDisabled);

            std.debug.print("GLFW Init Succeeded.\n", .{});

            return Self{
                .camera = camera,
                .window = window,
                .deltaTime = 0.04,
                .currentShader = undefined,
                .VAOs = undefined,
            };
        }
        pub fn keyboardWalk(self: *Self) void {
            if (glfw.getKey(self.window, glfw.KeyW) == glfw.Press) {
                self.camera.pos = Vec3.sub(self.camera.pos, Vec3.mulScalar(self.camera.front, self.deltaTime));
            }
            if (glfw.getKey(self.window, glfw.KeyS) == glfw.Press) {
                self.camera.pos = Vec3.add(self.camera.pos, Vec3.mulScalar(self.camera.front, self.deltaTime));
            }
            if (glfw.getKey(self.window, glfw.KeyA) == glfw.Press) {
                self.camera.pos = Vec3.add(self.camera.pos, Vec3.mulScalar(self.camera.right, self.deltaTime));
            }
            if (glfw.getKey(self.window, glfw.KeyD) == glfw.Press) {
                self.camera.pos = Vec3.sub(self.camera.pos, Vec3.mulScalar(self.camera.right, self.deltaTime));
            }
            if (glfw.getKey(self.window, glfw.KeySpace) == glfw.Press) {
                self.camera.pos = Vec3.sub(self.camera.pos, Vec3.mulScalar(self.camera.up, self.deltaTime));
            }
            if (glfw.getKey(self.window, glfw.KeyLeftControl) == glfw.Press) {
                self.camera.pos = Vec3.add(self.camera.pos, Vec3.mulScalar(self.camera.up, self.deltaTime));
            }
        }

        pub fn update(self: *Self, normals: [6]Vec3) void {
            self.keyboardWalk();
            processInput(self.window);
            glfw.getCursorPos(self.window, &xpos, &ypos);
            mouseUpdate(&self.camera, xpos, ypos);

            gl.ClearColor(0.35, 0.4, 0.95, 1.0);
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            gl.UseProgram(self.currentShader.shaderProgram);
            self.currentShader.setMat4(self.camera.getViewMatrix(), "view");
            self.currentShader.setVec4(zlm.Vec4.init(0.05, 0.65, 0.2, 1.0), "objectColor");
            self.currentShader.setVec4(zlm.Vec4.init(1.0, 1.0, 1.0, 1.0), "lightColor");
            self.currentShader.setVec3(self.camera.pos, "lightPos");
            for (0..6) |i| {
                self.currentShader.setVec3(normals[i], "normal");
                gl.BindVertexArray(self.VAOs[i]);
                gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
            }

            glfw.swapBuffers(self.window);
            glfw.pollEvents();
        }
        pub fn deinit(self: Self) void {
            glfw.destroyWindow(self.window);
            glfw.terminate();
            gl.makeProcTableCurrent(null);
        }
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game = try Game().init(90, Vec3.init(0, 0, 3), Vec3.init(0, 0, 0));
    defer game.deinit();

    var procs: gl.ProcTable = undefined;
    if (!procs.init(glfw.getProcAddress)) return error.InitFailed;
    gl.makeProcTableCurrent(&procs);

    const shaderProgram = try shader.ShaderProgram().init(
        allocator,
        "src/shaders/vshader.glsl",
        "src/shaders/fshader.glsl",
    );
    defer shaderProgram.deinit();

    game.currentShader = shaderProgram;

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

    const normals: [6]Vec3 = .{
        Vec3.init(0, 0, -1),
        Vec3.init(0, 0, 1),
        Vec3.init(-1, 0, 0),
        Vec3.init(1, 0, 0),
        Vec3.init(0, -1, 0),
        Vec3.init(0, 1, 0),
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

    
    const offsets = blk: {
        var offsets: [10]Vec3 = undefined;
        for (0..10) |i| {
            for (0..10) |j| {
                offsets[10*i + j] = Vec3.init(i,j,0);
            }
        }
        break :blk ;
    };

    game.currentShader.setVec3Arr()
    game.VAOs = VAOs;


    gl.Enable(gl.DEPTH_TEST);

    // Specify and link our vertext attribute description

    glfw.swapInterval(1); //V-sync

    const modelMat = Mat4.identity().rotate(45, Vec3.init(0.5, 0.5, 0));
    const viewMat = game.camera.getViewMatrix();
    const projMat = game.camera.projMatrix;

    gl.UseProgram(shaderProgram.shaderProgram);
    shaderProgram.setMat4(modelMat, "model");
    shaderProgram.setMat4(viewMat, "view");
    shaderProgram.setMat4(projMat, "projection");

    while (!glfw.windowShouldClose(game.window)) {
        game.update(normals);
    }
}

fn mouseUpdate(camera: *_camera.Camera(), xposIn: f64, yposIn: f64) void {
    if (firstMouse) {
        lastX = xposIn;
        lastY = yposIn;
        firstMouse = false;
    }

    const xOffset = xposIn - lastX;
    const yOffset = lastY - yposIn;

    lastX = xposIn;
    lastY = yposIn;

    camera.processMouseMovement(xOffset, yOffset);
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

test {
    _ = @import("matrix_util.zig");
}
