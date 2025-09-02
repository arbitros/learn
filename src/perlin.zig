const std = @import("std");

pub fn perlin(chunkSize: u32) type {
    struct {
        pub fn randomFromCoord(x: i32, y: i32) f32 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(std.mem.asBytes(&x));
            hasher.update(std.mem.asBytes(&y));

            var prng = std.Random.DefaultPrng.init(hasher.final());
            const rand = prng.random();
            return rand.float(f32);
        }

        pub fn perlin(x: i32, y: i32, density: u32) [chunkSize]f32 {
            const zone_x: i32 = @divFloor(x, density);
            const zone_y: i32 = @divFloor(y, density);
            const zone = zone_x * 10 + zone_y;

            var prng = std.Random.DefaultPrng.init(zone);
            const rand = prng.random();
            const vectors: [4]Vector = .{
                Vector{ .x = rand.float(f32), .y = rand.float(f32), .pos = .{ zone_x, zone_y } },
            };
        }
        const Vector = struct {
            x: f32,
            y: f32,
            pos: [2]f32,
        };
    };
}
