const zlm = @import("zig_matrix");
const std = @import("std");
const math = std.math;

const Vec3 = zlm.Vec3;
const Mat4 = zlm.Mat4x4;

pub fn Camera() type {
    return struct {
        const Self = @This();
        const UP = zlm.Vec3.init(0.0, 1.0, 0.0);
        const SENSITIVITY = 0.1;
        const SPEED = 2.5;

        cameraPos: Vec3,
        cameraFront: Vec3,
        cameraUp: Vec3,
        cameraRight: Vec3,

        mouseSens: f32,
        movementSpeed: f32,
        yaw: f32,
        pitch: f32,

        projMatrix: zlm.Mat4x4,
        viewMatrix: zlm.Mat4x4,

        pub fn init(fov: f32, cameraPos: Vec3, objPos: Vec3) Self {
            const projMatrix = blk: {
                const n = 0.1;
                const t = math.tan(math.degreesToRadians(fov / 2)) * n;
                const r = t;
                const f = 100;
                const projmat = zlm.Mat4x4.init(
                    zlm.Vec4.init(n / r, 0, 0, 0),
                    zlm.Vec4.init(0, n / t, 0, 0),
                    zlm.Vec4.init(0, 0, -(f + n) / (f - n), -2 * f * n / (f - n)),
                    zlm.Vec4.init(0, 0, -1, 0),
                );
                break :blk projmat;
            };

            const cameraDir = Vec3.norm(objPos.sub(cameraPos)); //camera vectors
            const cameraRight = Vec3.cross(UP, cameraDir);
            const cameraUp = Vec3.cross(cameraRight, cameraDir);
            return Self{
                .cameraPos = cameraPos,
                .cameraFront = cameraDir,
                .cameraUp = cameraUp,
                .cameraRight = cameraRight,
                .projMatrix = projMatrix,
                .viewMatrix = lookAt(cameraPos, objPos),
                .mouseSens = SENSITIVITY,
                .movementSpeed = SPEED,
                .yaw = 0,
                .pitch = 0,
            };
        }
        pub fn lookAt(cameraPos: Vec3, objPos: Vec3) Mat4 {
            const cameraDir = Vec3.norm(objPos.sub(cameraPos)); //camera vectors
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
            const viewMat = cameraSpace.mul(cameraPosMat);
            return viewMat;
        }

        pub fn getViewMatrix(self: Self) Mat4 {
            return lookAt(self.cameraPos, self.cameraPos.add(self.cameraFront));
        }

        pub fn updateViewMatrix(self: *Self) void {
            self.viewMatrix = self.getViewMatrix();
        }

        pub fn processMouseMovement(self: *Self, xOffsetIn: f64, yOffsetIn: f64) void {
            const xOffset = xOffsetIn * self.mouseSens;
            const yOffset = yOffsetIn * self.mouseSens;

            self.yaw += @as(f32, @floatCast(xOffset));
            self.pitch += @as(f32, @floatCast(yOffset));

            if (self.pitch > 89) {
                self.pitch = 89;
            }
            if (self.pitch < -89) {
                self.pitch = -89;
            }
            self.updateCameraVectors();
        }
        pub fn updateCameraVectors(self: *Self) void {
            const front = Vec3.init(
                math.cos(math.degreesToRadians(self.yaw)) * math.cos(math.degreesToRadians(self.pitch)),
                math.sin(math.degreesToRadians(self.pitch)),
                math.sin(math.degreesToRadians(self.yaw)) * math.cos(math.degreesToRadians(self.pitch)),
            );

            self.cameraFront = front.norm();
            self.cameraRight = Vec3.norm(self.cameraFront.cross(UP));
            self.cameraUp = Vec3.norm(self.cameraRight.cross(self.cameraFront));

            self.updateViewMatrix();
        }
    };
}

test {
    // const camera1 = Camera().init(90);
    // const matrix = camera1.lookAt(Vec3.init(1, 1, 1), Vec3.init(0, 0, 0));
    // std.debug.print("{any}", .{matrix.elements});
}
