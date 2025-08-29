const glfw = @import("glfw");
const std = @import("std");
const gl = @import("gl");
const zlm = @import("zig_matrix");
const _shader = @import("shader.zig");
const _camera = @import("camera.zig");
const _chunk = @import("chunk.zig");

const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4x4;
const iVec3 = zlm.GenericVector(3, i32);

pub fn Game(CHUNK_SIZE: u32, windowWidth: u32, windowHeight: u32) type {
    const ChunkMap = std.HashMap(Vec3, _chunk.Chunk(CHUNK_SIZE), _chunk.Chunk(CHUNK_SIZE).Context, 1);

    return struct {
        window: ?*glfw.Window,
        camera: _camera.Camera(windowWidth, windowHeight),
        deltaTime: f32,
        currentShader: _shader.ShaderProgram(),
        VAOs: [6]c_uint,
        chunkMap: ChunkMap,

        const Self = @This();

        pub fn init(FOV: f32, obj: Vec3, objPos: Vec3, window: ?*glfw.Window, allocator: std.mem.Allocator) anyerror!Self {
            const camera = _camera.Camera(windowWidth, windowHeight).init(FOV, obj, objPos, @as(f32, @floatFromInt(windowWidth / windowHeight)));

            std.debug.print("GLFW Init Succeeded.\n", .{});

            var shader: _shader.ShaderProgram() = try _shader.ShaderProgram().init(
                allocator,
                "src/shaders/vshader.glsl",
                "src/shaders/fshader.glsl",
            );

            gl.UseProgram(shader.shaderProgram);
            shader.setInt(CHUNK_SIZE, "chunkSize");
            shader.setVec4(zlm.Vec4.init(0.05, 0.65, 0.2, 1.0), "objectColor");
            shader.setVec4(zlm.Vec4.init(1.0, 1.0, 1.0, 1.0), "lightColor");

            var chunkMap = ChunkMap.init(allocator);
            for (0..1) |i| {
                const chunk = try _chunk.Chunk(CHUNK_SIZE).init(&shader, Vec3.init(@as(f32, @floatFromInt(CHUNK_SIZE * i)), 0, 0), allocator);
                try chunkMap.put(chunk.pos, chunk);
            }

            return Self{
                .camera = camera,
                .window = window,
                .deltaTime = 0.04,
                .currentShader = shader,
                .VAOs = undefined,
                .chunkMap = chunkMap,
            };
        }
        pub fn deinit(self: *Self) void {
            glfw.destroyWindow(self.window);
            glfw.terminate();

            var iterator = self.chunkMap.iterator();
            while (iterator.next()) |entry| {
                entry.value_ptr.deinit();
            }
            self.chunkMap.deinit();
            self.currentShader.deinit();

            gl.makeProcTableCurrent(null);
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

        pub fn update(self: *Self) void {
            self.keyboardWalk();
            processInput(self.window);
            glfw.getCursorPos(self.window, &self.camera.mouseVar.xpos, &self.camera.mouseVar.ypos);
            self.camera.mouseUpdate(self.camera.mouseVar.xpos, self.camera.mouseVar.ypos);
        }

        pub fn draw(self: Self) void {
            gl.ClearColor(0.35, 0.4, 0.95, 1.0);
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            gl.UseProgram(self.currentShader.shaderProgram);
            self.currentShader.setMat4(self.camera.getViewMatrix(), "view");
            self.currentShader.setVec3(self.camera.pos, "lightPos");
            self.currentShader.setInt(CHUNK_SIZE, "chunkSize");
            self.currentShader.setVec4(zlm.Vec4.init(0.05, 0.65, 0.2, 1.0), "objectColor");
            self.currentShader.setVec4(zlm.Vec4.init(1.0, 1.0, 1.0, 1.0), "lightColor");

            var iterator = self.chunkMap.iterator();
            while (iterator.next()) |entry| {
                entry.value_ptr.draw(self.VAOs);
            }

            glfw.swapBuffers(self.window);
            glfw.pollEvents();
        }

        pub fn framebuffer_size_callback(window: glfw.Window, width: u32, height: u32) void {
            _ = window;
            gl.Viewport(0, 0, @as(c_int, @intCast(width)), @as(c_int, @intCast(height)));
        }

        pub fn processInput(window: ?*glfw.Window) void {
            if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
                glfw.setWindowShouldClose(window, true);
            }
        }
    };
}

test {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var hashmap = std.HashMap(iVec3, i32, Game(4, 4, 4).Context, 1).init(allocator);
    defer hashmap.deinit();
    try hashmap.put(iVec3.init(0, 0, 0), -5);
    try hashmap.put(iVec3.init(1, 0, 0), -7);
    try std.testing.expect(hashmap.contains(iVec3.init(0, 0, 0)) == true);
    var iterator = hashmap.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("{any}", .{entry});
    }
}
