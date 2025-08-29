const zlm = @import("zig_matrix");

pub fn getMat4Ptr(mat4: zlm.Mat4x4) [16]f32 {
    var arr: [16]f32 = undefined;
    for (0..4) |i| {
        const row: [4]f32 = mat4.row(@intCast(i)).elements;
        @memcpy(arr[4 * i .. 4 * (i + 1)], &row);
    }
    return arr;
}

//TODO rotation

test {}
