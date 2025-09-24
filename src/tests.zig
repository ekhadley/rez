const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const rez = @import("rez");
const Pattern = rez.Pattern;

const MatchAssertEqualFailed = error{};

pub fn expectMatch(p: *Pattern, str: []const u8, expected: ?[]const u8) !void {
    if (p.match(str)) |match| {
        if (expected) |expected_str| {
            return testing.expectEqualStrings(expected_str, match) catch { // check the string matches are the same
                std.debug.print("\x1b[0;31m input: '{s}', expected match: '{s}', but returned: '{s}'\x1b[0m", .{ str, expected_str, match });
                return error.MatchAssertEqualFailed;
            };
        } else {
            std.debug.print("\x1b[0;31m input: '{s}', expected no match, but returned: '{s}'\x1b[0m", .{ str, match });
            return error.MatchAssertEqualFailed;
        }
    } else {
        if (expected) |expected_str| { // expected was not null
            std.debug.print("\x1b[0;31m input: '{s}', expected '{s}', but returned null \x1b[0m", .{ str, expected_str });
            return error.MatchAssertEqualFailed;
        }
    }
    return;
}

test "manual pattern full match '.*b'" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    p.setInitial(s0);
    p.setFinal(s1);
    p.connect(s0, s1, 'b');
    p.connect(s1, s1, 'b');

    try expect(p.fullmatch("123b"));
    try expect(p.fullmatch("bbb"));
    try expect(p.fullmatch("b23b"));
    try expect(!p.fullmatch("a"));
    try expect(!p.fullmatch("icba"));
    try expect(!p.fullmatch(""));
}

test "manual pattern fullmatch 'a.*c'" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    const s2 = p.addState();
    const s3 = p.addState();
    p.setInitial(s0);
    p.setDefault(s0, s1);
    p.setDefault(s1, s1);
    p.connect(s0, s2, 'a');
    p.setDefault(s2, s2);
    p.connect(s2, s3, 'c');
    p.setDefault(s3, s2);
    p.connect(s3, s2, 'c');
    p.setFinal(s3);

    try expect(p.fullmatch("abc"));
    try expect(p.fullmatch("a123c"));
    try expect(p.fullmatch("ac"));
    try expect(!p.fullmatch("aca"));
    try expect(!p.fullmatch("acaca"));
    try expect(!p.fullmatch("cacac"));
    try expect(!p.fullmatch(""));
}

test "manual pattern match 'a.c'" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    const s2 = p.addState();
    const s3 = p.addState();
    p.setInitial(s0);
    p.setFinal(s3);
    p.setDefault(s1, s2);
    p.connect(s0, s1, 'a');
    p.connect(s2, s3, 'c');

    try expectMatch(&p, "abc", "abc");
    try expectMatch(&p, "__azc__", "azc");
    try expectMatch(&p, "__a_c__", "a_c");
    try expectMatch(&p, "ac", null);
    try expectMatch(&p, "_ac_", null);
    try expectMatch(&p, "abbc", null);
}

test "manual pattern match 'a.*c'" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    const s2 = p.addState();
    const s3 = p.addState();
    p.setInitial(s0);
    p.setDefault(s0, 0);
    p.connect(s0, s1, 'a');
    p.setDefault(s1, s1);

    try expectMatch(&p, "abc", "abc");
    try expectMatch(&p, "abcbc", "abcbc");
    try expectMatch(&p, "__abc__", "abc");
    try expectMatch(&p, "--[a, b, c]--", "a, b, c");
    try expectMatch(&p, "__abc_abc__", "abc_abc");
    try expectMatch(&p, "__ac", "ac");
    try expectMatch(&p, "abracadabra", "abrac");
    try expectMatch(&p, "abacus", "abac");
    try expectMatch(&p, "_caaa", null);
    try expectMatch(&p, "cabrakadabra", null);
    try expectMatch(&p, "a", null);
    try expectMatch(&p, "ab", null);
    try expectMatch(&p, "", null);
}
