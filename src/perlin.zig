const std = @import("std");
const zlm = @import("zig_matrix");

const Vec2 = zlm.Vec2;
const Vec3 = zlm.Vec3;
const iVec2 = zlm.GenericVector(2, i32);

const print = std.debug.print;

pub fn Perlin(chunkSize: u32) type {
    return struct {
        const gridSize: u32 = chunkSize * chunkSize;

        pub fn randomFromCoord(x: i32, y: i32) f32 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(std.mem.asBytes(&x));
            hasher.update(std.mem.asBytes(&y));

            var prng = std.Random.DefaultPrng.init(hasher.final());
            const rand = prng.random();
            return rand.float(f32);
        }

        pub fn generate(chunkPos: iVec2, density: u64) [gridSize]f32 {
            const zone = blk: {
                const zone_x: u64 = if (chunkPos.x() > 0) @divFloor(@as(u64, @intCast(chunkPos.x())), density) else 0xFFFFFFFFFF - @divFloor(@as(u64, @intCast(-chunkPos.x())), density);
                const zone_y: u64 = if (chunkPos.x() > 0) @divFloor(@as(u64, @intCast(chunkPos.y())), density) else 0xFFFFFFFFFF - @divFloor(@as(u64, @intCast(-chunkPos.y())), density);
                break :blk zone_x * 10 + zone_y;
            };
            // print("{d}\n", .{zone});
            var prng = std.Random.DefaultPrng.init(zone); //ADD BACK
            const rand = prng.random();
            const vectors: [4]zlm.Vec2 = .{
                Vec2.init(rand.float(f32), rand.float(f32)),
                Vec2.init(rand.float(f32), rand.float(f32)),
                Vec2.init(rand.float(f32), rand.float(f32)),
                Vec2.init(rand.float(f32), rand.float(f32)),
            };

            const x = @as(f32, @floatFromInt(chunkPos.x()));
            const y = @as(f32, @floatFromInt(chunkPos.y()));
            const denseF = @as(f32, @floatFromInt(density));
            const denseVectors: [4]Vec2 = .{ //fix this shit, draw on paper to get the right shit
                .init(x, y),
                .init(x, if (x > 0) denseF + y else -denseF + y),
                .init(if (x > 0) denseF + x else -denseF + x, if (x > 0) denseF + y else -denseF + y),
                .init(if (x > 0) denseF + x else -denseF + x, y),
            };

            const chunkSizeF = @as(f32, @floatFromInt(chunkSize));

            const chunkVectors: [4]Vec2 = .{
                .init(x, y),
                .init(x, if (x > 0) chunkSizeF + y else -chunkSizeF + y),
                .init(if (x > 0) chunkSizeF + x else -chunkSizeF + x, if (x > 0) chunkSizeF + y else -chunkSizeF + y),
                .init(if (x > 0) chunkSizeF + x else -chunkSizeF + x, y),
            };

            const corners = blk: {
                var corners: [4]f32 = undefined;
                for (0..4) |i| {
                    var val: f32 = 0;
                    for (0..4) |j| {
                        val += Vec2.dot(vectors[i], denseVectors[j].sub(chunkVectors[j]));
                    }
                    corners[i] = val / 20;
                }
                break :blk corners;
            };
            // print("{d}", .{corners});

            var array: [gridSize]f32 = undefined;
            var sides: [2][chunkSize]f32 = undefined;
            for (0..2) |i| {
                const a = corners[i * 2];
                const b = corners[i * 2 + 1];
                for (0..chunkSize) |j| {
                    const t: f32 = @as(f32, @floatFromInt(j / @as(usize, @intCast(chunkSize))));

                    sides[i][j] = interpolate(a, b, t);
                }
            }
            for (0..chunkSize) |i| {
                const a = sides[0][i];
                const b = sides[1][i];
                for (0..chunkSize) |j| {
                    const t: f32 = @as(f32, @floatFromInt(j / @as(usize, @intCast(chunkSize))));
                    array[i * chunkSize + j] = interpolate(a, b, t) * chunkSize;
                    // std.debug.print("{d}{d}\n", .{ a, b });
                }
            }

            var _prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
            const _rand = _prng.random();
            for (0..chunkSize) |i| {
                array[i] = (_rand.float(f32) + 1) * 14;
            }

            return array;
        }
        fn smoothstep(tIn: f32) f32 {
            const t = @max(0, @min(1, tIn));
            return t * t * (3 - 2 * t);
        }
        pub fn interpolate(a: f32, b: f32, t: f32) f32 {
            const smooth = smoothstep(t);
            return a + smooth * (b - a);
        }
    };
}

test {
    const perlin = Perlin(8);
    const noise = perlin.generate(iVec2.init(0, 0), 32);
    _ = noise;
    // std.debug.print("{any}\n", .{noise});
}
