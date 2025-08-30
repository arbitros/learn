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
    const ChunkMap = std.HashMap(iVec3, _chunk.Chunk(CHUNK_SIZE), _chunk.Chunk(CHUNK_SIZE).Context, 1);
    const VIEW_RANGE: u32 = 6;

    return struct {
        window: ?*glfw.Window,
        camera: _camera.Camera(windowWidth, windowHeight),
        deltaTime: f32,
        currentShader: _shader.ShaderProgram(),
        currentChunk: *_chunk.Chunk(CHUNK_SIZE),
        VAOs: [6]c_uint,
        chunkMap: ChunkMap,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(FOV: f32, obj: Vec3, objPos: Vec3, window: ?*glfw.Window, allocator: std.mem.Allocator) anyerror!Self {
            const camera = _camera.Camera(windowWidth, windowHeight).init(FOV, obj, objPos, @as(f32, @floatFromInt(windowWidth / windowHeight)));

            var shader: _shader.ShaderProgram() = try _shader.ShaderProgram().init(
                allocator,
                "src/shaders/vshader.glsl",
                "src/shaders/fshader.glsl",
            );

            gl.UseProgram(shader.shaderProgram);
            shader.setInt(CHUNK_SIZE, "chunkSize");
            shader.setVec3(zlm.Vec3.init(0.05, 0.65, 0.2), "objectColor");
            shader.setVec3(zlm.Vec3.init(1.0, 1.0, 1.0), "lightColor");
            shader.setMat4(camera.projMatrix, "projection");
            shader.setMat4(zlm.Mat4x4.identity(), "model");

            var chunkMap = ChunkMap.init(allocator);
            const chunkOrg = try _chunk.Chunk(CHUNK_SIZE).init(iVec3.init(0, 0, 0), allocator);
            try chunkMap.put(chunkOrg.pos, chunkOrg);

            var i: i32 = -@as(i32, @intCast(VIEW_RANGE / 2));
            var j: i32 = i;

            while (i <= VIEW_RANGE / 2) : (i += 1) {
                while (j <= VIEW_RANGE / 2) : (j += 1) {
                    if (i == 0 and j == 0) continue;
                    const chunk = try _chunk.Chunk(CHUNK_SIZE).init(iVec3.init(
                        @as(i32, @intCast(CHUNK_SIZE)) * i,
                        0,
                        @as(i32, @intCast(CHUNK_SIZE)) * j,
                    ), allocator);
                    try chunkMap.put(chunk.pos, chunk);
                    std.debug.print("Vec: {any}, Ptr: {*}\n", .{ chunk.pos, chunk.blocks });
                }
                j = -@as(i32, @intCast(VIEW_RANGE / 2));
            }

            return Self{
                .camera = camera,
                .window = window,
                .deltaTime = 0.04,
                .currentShader = shader,
                .currentChunk = chunkMap.getPtr(iVec3.init(0, 0, 0)) orelse return error.NoChunk,
                .VAOs = undefined,
                .chunkMap = chunkMap,
                .allocator = allocator,
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
                self.camera.pos = Vec3.sub(self.camera.pos, Vec3.mulScalar(self.camera.glob_up, self.deltaTime));
            }
            if (glfw.getKey(self.window, glfw.KeyLeftControl) == glfw.Press) {
                self.camera.pos = Vec3.add(self.camera.pos, Vec3.mulScalar(self.camera.glob_up, self.deltaTime));
            }
        }

        pub fn update(self: *Self) !void {
            self.keyboardWalk();
            processInput(self.window);
            glfw.getCursorPos(self.window, &self.camera.mouseVar.xpos, &self.camera.mouseVar.ypos);
            self.camera.mouseUpdate(self.camera.mouseVar.xpos, self.camera.mouseVar.ypos);

            self.camera.coordPos = iVec3.init(
                @as(i32, @intFromFloat(self.camera.pos.x())),
                @as(i32, @intFromFloat(self.camera.pos.y())),
                @as(i32, @intFromFloat(self.camera.pos.z())),
            );
            try self.chunkLoading();
        }

        pub fn chunkLoading(self: *Self) !void { // works one direction, memory leaks!!
            const pos = self.camera.coordPos;
            const chunkPos = self.currentChunk.pos;
            const maxView: i32 = VIEW_RANGE * CHUNK_SIZE;

            var unloaded: [VIEW_RANGE + 1]iVec3 = undefined;
            var loaded: [VIEW_RANGE + 1]iVec3 = undefined;
            if (pos.x() > chunkPos.x() + CHUNK_SIZE) {
                for (0..unloaded.len) |i| {
                    unloaded[i] = iVec3.init(
                        chunkPos.x() - maxView / 2,
                        0,
                        chunkPos.z() - maxView / 2 + @as(i32, @intCast(i * CHUNK_SIZE)),
                    );
                    loaded[i] = iVec3.init(
                        chunkPos.x() + maxView / 2 + CHUNK_SIZE,
                        0,
                        chunkPos.z() - maxView / 2 + @as(i32, @intCast(i * CHUNK_SIZE)),
                    );
                }
                // std.debug.print("playerPos: {any}", .{self.camera.coordPos});
                self.currentChunk = self.chunkMap.getPtr(iVec3.init(CHUNK_SIZE, 0, 0).add(self.currentChunk.pos)) orelse return error.what;
                try self.moveChunks(unloaded, loaded);
            }
            // if (pos.x() < chunkPos.x() - CHUNK_SIZE) {
            //     for (0..unloaded.len) |i| {
            //         unloaded[i] = iVec3.init(
            //             chunkPos.x() + maxView / 2,
            //             0,
            //             chunkPos.z() + maxView / 2 - @as(i32, @intCast(i * CHUNK_SIZE)),
            //         );
            //         loaded[i] = iVec3.init(
            //             chunkPos.x() - maxView / 2,
            //             0,
            //             chunkPos.z() + maxView / 2 + @as(i32, @intCast(i * CHUNK_SIZE)),
            //         );
            //     }
            //     self.currentChunk = self.chunkMap.getPtr(iVec3.init(CHUNK_SIZE, 0, 0).add(self.currentChunk.pos)) orelse return error.what;
            // }
        }
        fn moveChunks(self: *Self, unloaded: [VIEW_RANGE + 1]iVec3, loaded: [VIEW_RANGE + 1]iVec3) !void {
            var chunk: *_chunk.Chunk(CHUNK_SIZE) = undefined;
            for (0..unloaded.len) |i| {
                chunk = self.chunkMap.getPtr(unloaded[i]) orelse return error.noChunkFound;
                // std.debug.print("chunkPos: {any}, Ptr: {*}\n", .{ unloaded[i], chunk.blocks });
                chunk.deinit();
                _ = self.chunkMap.remove(unloaded[i]);
                const newChunk = try _chunk.Chunk(CHUNK_SIZE).init(loaded[i], self.allocator);
                try self.chunkMap.put(loaded[i], newChunk);
                std.debug.print("chunkPos: {any}, Ptr: {*}\n", .{ loaded[i], newChunk.blocks });
            }
        }

        pub fn draw(self: Self) void {
            gl.ClearColor(0.35, 0.4, 0.95, 1.0);
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            gl.UseProgram(self.currentShader.shaderProgram);
            self.currentShader.setMat4(self.camera.getViewMatrix(), "view");
            self.currentShader.setVec3(self.camera.pos, "lightPos");

            var iterator = self.chunkMap.iterator();
            while (iterator.next()) |entry| {
                entry.value_ptr.draw(self.VAOs, self.currentShader);
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
