const std = @import("std");
const zlm = @import("zig_matrix");
const gl = @import("gl");
const _shader = @import("shader.zig");
const Vec3 = zlm.Vec3;
const iVec3 = zlm.GenericVector(3, i32);

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
        pos: Vec3,
        shader: *_shader.ShaderProgram(),
        playerPresent: bool,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub const Context = struct {
            pub fn hash(self: @This(), key: Vec3) u64 {
                _ = self;
                return @as(u64, @intFromFloat(100 * key.x() + 10 * key.y() + key.z()));
            }
            pub fn eql(self: @This(), key1: Vec3, key2: Vec3) bool {
                _ = self;
                return Vec3.eql(key1, key2);
            }
        };

        pub fn init(shader: *_shader.ShaderProgram(), pos: Vec3, allocator: std.mem.Allocator) !Self {
            const blocks = try allocator.alloc(u8, MAX_BLOCKS);
            @memset(blocks, 1);
            const panels = try allocator.alloc(u8, 6 * MAX_BLOCKS); //Note, flat array, arr[p*MAX_BLOCKS + b] = arr[p][b]
            @memset(panels, 1);

            // for (0..6) |i| {
            //     panels[i * MAX_BLOCKS + 0] = 1;
            // }

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
                    @ptrCast(&panels),
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
                .shader = shader,
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
        pub fn draw(self: Self, VAOs: [6]c_uint) void {
            for (0..6) |i| {
                self.shader.setVec3(normals[i], "normal");
                const unit = @as(c_uint, @intCast(i));
                gl.BindVertexArray(VAOs[i]);
                gl.ActiveTexture(gl.TEXTURE0 + unit);
                gl.BindTexture(gl.TEXTURE_3D, self.blockInfo[i]);
                self.shader.setInt(gl.TEXTURE0 + unit, "chunkData");
                self.shader.setVec3(self.pos, "chunkPos");
                gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null, @intCast(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE));
            }
        }
    };
}
