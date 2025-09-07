const std = @import("std");
const zlm = @import("zig_matrix");
const gl = @import("gl");
const _shader = @import("shader.zig");
const _perlin = @import("perlin.zig");

const Vec3 = zlm.Vec3;
const iVec3 = zlm.GenericVector(3, i32);
const iVec2 = zlm.GenericVector(2, i32);

pub fn Chunk(CHUNK_SIZE: u32) type {
    const normals: [6]Vec3 = .{
        Vec3.init(0, 0, -1),
        Vec3.init(0, 0, 1),
        Vec3.init(-1, 0, 0),
        Vec3.init(1, 0, 0),
        Vec3.init(0, -1, 0),
        Vec3.init(0, 1, 0),
    };

    const MAX_BLOCKS = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;
    return struct {
        // 0: air, 1: solid, 2: targeted
        panels: []u8, //MAX_BLOCKS*6
        blocks: []u8, //MAX_BLOCKS
        corners: [4]f32,
        blockInfo: [6]c_uint,
        pos: iVec3,
        playerPresent: bool,
        changed: bool,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub const Context = struct {
            pub fn hash(self: @This(), key: iVec3) u64 {
                _ = self;
                const y: u64 = if (key.y() < 0) @as(u64, @intCast(-key.y())) + CHUNK_SIZE + 2 else @as(u64, @intCast(key.y()));
                const x: u64 = if (key.x() < 0) 0xFFFFFFFFFF - @divFloor(@as(u32, @intCast(-key.x())), @as(u64, @intCast(CHUNK_SIZE))) else @intCast(key.x());
                const z: u64 = if (key.z() < 0) 0xFFFFFFFFFF - @divFloor(@as(u32, @intCast(-key.z())), @as(u64, @intCast(CHUNK_SIZE))) else @intCast(key.z());
                return @as(u64, @intCast(100 * x + 10 * y + z));
            }
            pub fn hashNo(key: iVec3) u64 {
                const y: u64 = if (key.y() < 0) @as(u64, @intCast(-key.y())) + CHUNK_SIZE + 2 else @as(u64, @intCast(key.y()));
                const x: u64 = if (key.x() < 0) 0xFFFFFFFFFF - @divFloor(@as(u32, @intCast(-key.x())), @as(u64, @intCast(CHUNK_SIZE))) else @intCast(key.x());
                const z: u64 = if (key.z() < 0) 0xFFFFFFFFFF - @divFloor(@as(u32, @intCast(-key.z())), @as(u64, @intCast(CHUNK_SIZE))) else @intCast(key.z());
                return @as(u64, @intCast(100 * x + 10 * y + z));
            }
            pub fn eql(self: @This(), key1: iVec3, key2: iVec3) bool {
                _ = self;
                return iVec3.eql(key1, key2);
            }
        };

        pub fn init(pos: iVec3, chunkMap: anytype, allocator: std.mem.Allocator) !Self {
            const blocks = try allocator.alloc(u8, MAX_BLOCKS);
            @memset(blocks, 0);

            const zone = Context.hashNo(pos);
            var prng = std.Random.DefaultPrng.init(zone);
            const rand = prng.random();

            var corners: [4]f32 = .{
                (rand.float(f32) + 1) * CHUNK_SIZE / 2 - 1,
                (rand.float(f32) + 1) * CHUNK_SIZE / 2 - 1,
                (rand.float(f32) + 1) * CHUNK_SIZE / 2 - 1,
                (rand.float(f32) + 1) * CHUNK_SIZE / 2 - 1,
            };
            // std.debug.print("pos: {any} cornersInit: {any}\n", .{ pos, corners });

            var chunk = chunkMap.getPtr(pos.sub(iVec3.init(0, 0, CHUNK_SIZE)));
            if (chunk) |chunkPtr| {
                corners[0] = chunkPtr.corners[1];
                corners[2] = chunkPtr.corners[3];
            }
            chunk = chunkMap.getPtr(pos.add(iVec3.init(0, 0, CHUNK_SIZE)));
            if (chunk) |chunkPtr| {
                corners[1] = chunkPtr.corners[0];
                corners[3] = chunkPtr.corners[2];
            }

            chunk = chunkMap.getPtr(pos.sub(iVec3.init(CHUNK_SIZE, 0, 0)));
            if (chunk) |chunkPtr| {
                corners[0] = chunkPtr.corners[2];
                corners[1] = chunkPtr.corners[3];
            }
            chunk = chunkMap.getPtr(pos.add(iVec3.init(CHUNK_SIZE, 0, 0)));
            if (chunk) |chunkPtr| {
                corners[3] = chunkPtr.corners[1];
                corners[2] = chunkPtr.corners[0];
            }

            chunk = chunkMap.getPtr(pos.sub(iVec3.init(CHUNK_SIZE, 0, CHUNK_SIZE)));
            if (chunk) |chunkPtr| {
                corners[0] = chunkPtr.corners[3];
            }
            chunk = chunkMap.getPtr(pos.add(iVec3.init(CHUNK_SIZE, 0, CHUNK_SIZE)));
            if (chunk) |chunkPtr| {
                corners[3] = chunkPtr.corners[0];
            }
            chunk = chunkMap.getPtr(pos.add(iVec3.init(-@as(i32, CHUNK_SIZE), 0, CHUNK_SIZE)));
            if (chunk) |chunkPtr| {
                corners[1] = chunkPtr.corners[2];
            }
            chunk = chunkMap.getPtr(pos.add(iVec3.init(CHUNK_SIZE, 0, -@as(i32, CHUNK_SIZE))));
            if (chunk) |chunkPtr| {
                corners[2] = chunkPtr.corners[1];
            }
            // std.debug.print("corners: {any}\n", .{corners});

            const perlin = _perlin.Perlin(CHUNK_SIZE);
            const simpleArr = perlin.generateSimple(corners);

            for (0..CHUNK_SIZE) |i| { //ADD BACK
                for (0..CHUNK_SIZE) |j| {
                    for (0..CHUNK_SIZE) |k| {
                        const idx = i * CHUNK_SIZE * CHUNK_SIZE + j * CHUNK_SIZE + k;
                        if (@as(f32, @floatFromInt(j)) <= simpleArr[i * CHUNK_SIZE + k]) blocks[idx] = 1;
                    }
                }
            }

            const panels = try allocator.alloc(u8, 6 * MAX_BLOCKS); //Note, flat array, arr[p*MAX_BLOCKS + b] = arr[p][b]
            @memset(panels, 0);

            for (0..MAX_BLOCKS) |i| {
                if (blocks[i] == 1) {
                    for (0..6) |j| {
                        panels[j * MAX_BLOCKS + i] = 1;
                    }
                } else {
                    for (0..6) |j| {
                        panels[j * MAX_BLOCKS + i] = 0;
                    }
                }
            }

            var blockInfo: [6]c_uint = undefined;

            gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
            for (0..6) |i| {
                gl.GenTextures(1, @ptrCast(&blockInfo[i]));
                gl.BindTexture(gl.TEXTURE_3D, blockInfo[i]);
                gl.TexImage3D(
                    gl.TEXTURE_3D,
                    0,
                    gl.R8UI,
                    CHUNK_SIZE,
                    CHUNK_SIZE,
                    CHUNK_SIZE,
                    0,
                    gl.RED_INTEGER,
                    gl.UNSIGNED_BYTE,
                    if (i < 6) @ptrCast(panels[i * MAX_BLOCKS .. (i + 1) * MAX_BLOCKS]) else panels[5 * MAX_BLOCKS .. 6 * MAX_BLOCKS - 1],
                );
                gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
                gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
                gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
                gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
                gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);
            }

            return Self{
                .panels = panels,
                .blocks = blocks,
                .blockInfo = blockInfo,
                .corners = corners,
                .pos = pos,
                .playerPresent = true,
                .changed = false,
                .allocator = allocator,
            };
        }

        pub fn updateSample3D(self: *Self) void {
            const blockInfo = self.blockInfo;
            const panels = self.panels;

            gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
            for (0..6) |i| {
                gl.BindTexture(gl.TEXTURE_3D, blockInfo[i]);
                gl.TexImage3D(
                    gl.TEXTURE_3D,
                    0,
                    gl.R8UI,
                    CHUNK_SIZE,
                    CHUNK_SIZE,
                    CHUNK_SIZE,
                    0,
                    gl.RED_INTEGER,
                    gl.UNSIGNED_BYTE,
                    if (i < 6) @ptrCast(panels[i * MAX_BLOCKS .. (i + 1) * MAX_BLOCKS]) else panels[5 * MAX_BLOCKS .. 6 * MAX_BLOCKS - 1],
                );
            }
        }
        pub fn deinit(self: Self) void {
            self.allocator.free(self.panels);
            self.allocator.free(self.blocks);
        }
        pub fn determinePanels(self: *Self, chunkMap: anytype) void { //a bit performance boost: remove chunk edges at edges
            const panels = self.panels;
            const blocks = self.blocks;
            const pos = self.pos;
            const wid = CHUNK_SIZE;

            for (0..wid) |i| {
                for (0..wid) |j| {
                    for (0..wid) |k| {
                        const idx = wid * wid * i + wid * j + k;
                        if (k < CHUNK_SIZE - 1) {
                            if (blocks[idx + 1] != 0) {
                                panels[3 * MAX_BLOCKS + idx] = 0;
                            }
                        } else if (chunkMap.getPtr(pos.add(iVec3.init(wid, 0, 0)))) |chunkXN| {
                            if (chunkXN.blocks[wid * wid * i + wid * j + 0] != 0) {
                                panels[3 * MAX_BLOCKS + idx] = 0;
                            }
                        }
                        if (k != 0) {
                            if (blocks[idx - 1] != 0) {
                                panels[2 * MAX_BLOCKS + idx] = 0;
                            }
                        } else if (chunkMap.getPtr(pos.sub(iVec3.init(wid, 0, 0)))) |chunkXP| {
                            if (chunkXP.blocks[wid * wid * i + wid * j + wid - 1] != 0) {
                                panels[2 * MAX_BLOCKS + idx] = 0;
                            }
                        }

                        if (i < CHUNK_SIZE - 1) {
                            if (blocks[idx + wid * wid] != 0) {
                                panels[1 * MAX_BLOCKS + idx] = 0;
                            }
                        } else if (chunkMap.getPtr(pos.add(iVec3.init(0, 0, wid)))) |chunkZN| {
                            if (chunkZN.blocks[0 + wid * j + k] != 0) {
                                panels[1 * MAX_BLOCKS + idx] = 0;
                            }
                        }

                        if (i != 0) {
                            if (blocks[idx - wid * wid] != 0) {
                                panels[0 * MAX_BLOCKS + idx] = 0;
                            }
                        } else if (chunkMap.getPtr(pos.sub(iVec3.init(0, 0, wid)))) |chunkZP| {
                            if (chunkZP.blocks[wid * wid * (wid - 1) + wid * j + k] != 0) {
                                panels[0 * MAX_BLOCKS + idx] = 0;
                            }
                        }

                        if (j < CHUNK_SIZE - 1) {
                            if (blocks[idx + wid] != 0) {
                                panels[5 * MAX_BLOCKS + idx] = 0;
                            }
                        }
                        if (j != 0) {
                            if (blocks[idx - wid] != 0) {
                                panels[4 * MAX_BLOCKS + idx] = 0;
                            }
                        }
                        if (j == 0) {
                            panels[4 * MAX_BLOCKS + idx] = 0;
                        }
                    }
                }
            }
        }
        pub fn update(self: *Self) void {
            self.updateSample3D();
        }
        pub fn draw(self: Self, VAOs: [6]c_uint, shader: _shader.ShaderProgram()) void {
            for (0..6) |i| {
                shader.setVec3(normals[i], "normal");
                gl.BindVertexArray(VAOs[i]);
                gl.ActiveTexture(gl.TEXTURE0);
                gl.BindTexture(gl.TEXTURE_3D, self.blockInfo[i]);
                shader.setInt(gl.TEXTURE0, "chunkData");
                shader.setiVec3(self.pos, "chunkPos");
                gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null, @intCast(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE));
            }
        }
    };
}
