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
        blockInfo: [6]c_uint,
        pos: iVec3,
        playerPresent: bool,
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
            pub fn eql(self: @This(), key1: iVec3, key2: iVec3) bool {
                _ = self;
                return iVec3.eql(key1, key2);
            }
        };

        pub fn init(pos: iVec3, allocator: std.mem.Allocator) !Self {
            const blocks = try allocator.alloc(u8, MAX_BLOCKS);
            // const perlin = _perlin.Perlin(CHUNK_SIZE);
            // const perlArr = perlin.generate(iVec2.init(pos.x(), pos.y()), CHUNK_SIZE * 2);
            // for (0..CHUNK_SIZE) |i| {
            //     for (0..CHUNK_SIZE) |j| {
            //         for (0..CHUNK_SIZE) |k| { //PROBLEM::: HAS TF DO I DETERMINE HEIGHT???
            //             const idx = i * CHUNK_SIZE * CHUNK_SIZE + j * CHUNK_SIZE + k;
            //             if (@as(f32, @floatFromInt(j)) <= perlArr[j * CHUNK_SIZE + k]) blocks[idx] = 1;
            //         }
            //     }
            // }

            var prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
            const rand = prng.random();

            var noise: [CHUNK_SIZE * CHUNK_SIZE]f32 = undefined;

            for (0..CHUNK_SIZE) |i| {
                for (0..CHUNK_SIZE) |j| {
                    noise[i * CHUNK_SIZE + j] = (rand.float(f32) + 1) * 5;
                }
            }

            for (0..CHUNK_SIZE) |i| {
                for (0..CHUNK_SIZE) |j| {
                    for (0..CHUNK_SIZE) |k| {
                        const idx = i * CHUNK_SIZE * CHUNK_SIZE + j * CHUNK_SIZE + k;
                        if (@as(f32, @floatFromInt(j)) <= noise[i * CHUNK_SIZE + k]) blocks[idx] = 1;
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
                    if (i < 4) @ptrCast(panels[i * MAX_BLOCKS .. (i + 1) * MAX_BLOCKS]) else panels[5 * MAX_BLOCKS .. 6 * MAX_BLOCKS - 1],
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
                .pos = pos,
                .playerPresent = true,
                .allocator = allocator,
            };
        }
        pub fn deinit(self: Self) void {
            self.allocator.free(self.panels);
            self.allocator.free(self.blocks);
        }
        pub fn determinePanels(self: Self) void {
            _ = self;
            // for (0..MAX_BLOCKS) |i| {
            //     if (blocks[i] == )
            // }
        }
        pub fn update() void {}
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
