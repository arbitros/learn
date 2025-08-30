const zlm = @import("zig_matrix");
const std = @import("std");
const math = std.math;

const Vec3 = zlm.Vec3;
const iVec3 = zlm.GenericVector(3, i32);
const Mat4 = zlm.Mat4x4;

pub fn Camera(windowWidth: u32, windowHeight: u32) type {
    return struct {
        const Self = @This();
        const GLOBAL_UP = zlm.Vec3.init(0.0, 1.0, 0.0);
        const SENSITIVITY = 0.1;
        const SPEED = 2.5;

        pos: Vec3,
        coordPos: iVec3,
        front: Vec3,
        up: Vec3,
        glob_up: Vec3,
        right: Vec3,

        mouseSens: f32,
        movementSpeed: f32,
        yaw: f32,
        pitch: f32,

        mouseVar: Mouse,

        projMatrix: zlm.Mat4x4,

        pub const Mouse = struct {
            lastX: f64,
            lastY: f64,
            xpos: f64,
            ypos: f64,
            firstMouse: bool,

            pub fn init() Mouse {
                return Mouse{
                    .lastX = @as(f64, @floatFromInt(windowWidth / 2)),
                    .lastY = @as(f64, @floatFromInt(windowHeight / 2)),
                    .xpos = 0,
                    .ypos = 0,
                    .firstMouse = true,
                };
            }
        };

        pub fn init(fov: f32, pos: Vec3, objPos: Vec3, aspect: f32) Self {
            const projMatrix = blk: {
                const n = 0.1;
                const t = math.tan(math.degreesToRadians(fov / 2)) * n;
                const b = -t;
                const r = t * aspect;
                const l = -r;
                const f = 300;
                const projmat = zlm.Mat4x4.init(
                    zlm.Vec4.init(2 * n / (r - l), 0, (r + l) / (r - l), 0),
                    zlm.Vec4.init(0, 2 * n / (t - b), (t + b) / (t - b), 0),
                    zlm.Vec4.init(0, 0, -(f + n) / (f - n), -2 * f * n / (f - n)),
                    zlm.Vec4.init(0, 0, -1, 0),
                );
                break :blk projmat;
            };

            const front = Vec3.norm(objPos.sub(pos)); //camera vectors
            const right = Vec3.cross(GLOBAL_UP, front);
            const up = Vec3.cross(right, front);
            return Self{
                .pos = pos,
                .coordPos = iVec3.init(
                    @as(i32, @intFromFloat(pos.x())),
                    @as(i32, @intFromFloat(pos.y())),
                    @as(i32, @intFromFloat(pos.z())),
                ),
                .front = front,
                .up = up,
                .glob_up = GLOBAL_UP,
                .right = right,
                .projMatrix = projMatrix,
                .mouseSens = SENSITIVITY,
                .movementSpeed = SPEED,
                .yaw = 0,
                .pitch = 0,
                .mouseVar = Mouse.init(),
            };
        }
        pub fn lookAt(pos: Vec3, objPos: Vec3) Mat4 {
            const front = Vec3.norm(objPos.sub(pos)); //camera vectors
            const right = Vec3.norm(Vec3.cross(GLOBAL_UP, front));
            const up = Vec3.norm(Vec3.cross(right, front));

            const cameraSpace = zlm.Mat4x4.init(
                zlm.Vec4.init(right.x(), right.y(), right.z(), 0.0),
                zlm.Vec4.init(up.x(), up.y(), up.z(), 0.0),
                zlm.Vec4.init(front.x(), front.y(), front.z(), 0.0),
                zlm.Vec4.init(0.0, 0.0, 0.0, 1.0),
            );
            const posMat = zlm.Mat4x4.init(
                zlm.Vec4.init(1.0, 0.0, 0.0, -pos.x()),
                zlm.Vec4.init(0.0, 1.0, 0.0, -pos.y()),
                zlm.Vec4.init(0.0, 0.0, 1.0, -pos.z()),
                zlm.Vec4.init(0.0, 0.0, 0.0, 1.0),
            );
            const viewMat = posMat.mul(cameraSpace);
            return viewMat;
        }

        pub fn getViewMatrix(self: Self) Mat4 {
            return lookAt(self.pos, self.pos.add(self.front));
        }

        pub fn mouseUpdate(self: *Self, xposIn: f64, yposIn: f64) void {
            if (self.mouseVar.firstMouse) {
                self.mouseVar.lastX = xposIn;
                self.mouseVar.lastY = yposIn;
                self.mouseVar.firstMouse = false;
            }

            const xOffset = xposIn - self.mouseVar.lastX;
            const yOffset = self.mouseVar.lastY - yposIn;

            self.mouseVar.lastX = xposIn;
            self.mouseVar.lastY = yposIn;

            self.processMouseMovement(xOffset, yOffset);
        }

        pub fn processMouseMovement(self: *Self, xOffsetIn: f64, yOffsetIn: f64) void {
            const xOffset = xOffsetIn * self.mouseSens;
            const yOffset = yOffsetIn * self.mouseSens;

            const yaw = @as(f32, @floatCast(xOffset));
            const pitch = self.pitch + @as(f32, @floatCast(yOffset));
            if (pitch > 89) {
                self.pitch = 89;
            } else if (pitch < -89) {
                self.pitch = -89;
            } else {
                self.pitch = pitch;
            }

            self.yaw += yaw;

            self.updateCameraVectors();
        }

        pub fn updateCameraVectors(self: *Self) void {
            const front = Vec3.init(
                math.cos(math.degreesToRadians(self.yaw)) * math.cos(math.degreesToRadians(self.pitch)),
                math.sin(math.degreesToRadians(self.pitch)),
                math.sin(math.degreesToRadians(self.yaw)) * math.cos(math.degreesToRadians(self.pitch)),
            );

            self.front = front.norm();
            self.right = Vec3.norm(self.front.cross(GLOBAL_UP));
            self.up = Vec3.norm(self.right.cross(self.front));
        }
    };
}

test {
    // const camera1 = Camera().init(90);
    // const matrix = camera1.lookAt(Vec3.init(1, 1, 1), Vec3.init(0, 0, 0));
    // std.debug.print("{any}", .{matrix.elements});
}
