const zlm = @import("zig_matrix");
const std = @import("std");
const math = std.math;

const Vec3 = zlm.Vec3;

pub fn Camera() type {
    return struct {
        const Self = @This();
        const UP = zlm.Vec3.init(0.0, 1.0, 0.0);
        projMatrix: zlm.Mat4x4,
        pub fn init(fov: f32) Self {
            const projMatrix = blk: {
                const n = 1;
                const t = math.tan(fov) / 2 * n;
                const b = -t;
                const r = t;
                const l = -t;
                const f = 200;
                const projmat = zlm.Mat4x4.init(
                    zlm.Vec4.init(2 * n / (r - l), 0, (r + l) / (r - l), 0),
                    zlm.Vec4.init(0, 2 * n / (t - b), (t + b) / (t - b), 0),
                    zlm.Vec4.init(0, 0, -(f + n) / (f - n), -2 * f * n / (f - n)),
                    zlm.Vec4.init(0, 0, -1, 0),
                );
                break :blk projmat;
            };
            return Self{
                .projMatrix = projMatrix,
            };
        }
        pub fn lookAt(cameraPos: Vec3, objPos: Vec3) zlm.Mat4x4 {
            const cameraDir = Vec3.norm(-(cameraPos - objPos)); //camera vectors
            const cameraRight = Vec3.cross(UP, cameraDir);
            const cameraUp = Vec3.cross(cameraRight, cameraDir);

            const cameraSpace = zlm.Mat4x4.init(
                zlm.Vec4.init(cameraRight.x(), cameraRight.y(), cameraRight.z(), 0.0),
                zlm.Vec4.init(cameraUp.x(), cameraUp.y(), cameraUp.z(), 0.0),
                zlm.Vec4.init(cameraDir.x(), cameraDir.y(), cameraDir.z(), 0.0),
                zlm.Vec4.init(0.0, 0.0, 0.0, 1.0),
            );
            const cameraPosMat = zlm.Mat4x4.init(
                zlm.Vec4.init(1.0, 0.0, 0.0, -cameraPos.x()),
                zlm.Vec4.init(0.0, 1.0, 0.0, -cameraPos.y()),
                zlm.Vec4.init(0.0, 0.0, 1.0, -cameraPos.z()),
                zlm.Vec4.init(0.0, 0.0, 0.0, 1.0),
            );
            return cameraSpace.mul(cameraPosMat);
        }
    };
}

test {
    const camera = Camera().init(90);
    std.debug.print("{any}", .{camera});
}
