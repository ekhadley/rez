const std = @import("std");
const testing = std.testing;

pub export fn add(a: i32, b: i32) i32 {
    return b + a;
}

test "basic add functionality" {}
