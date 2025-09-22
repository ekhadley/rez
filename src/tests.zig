const std = @import("std");
const testing = std.testing;
const rez = @import("rez");
const Pattern = rez.Pattern;
const CaptureIterator = rez.CaptureIterator;

const MatchAssertEqualFailed = error{};

pub fn expectMatch(p: *Pattern, str: []const u8, expect: ?[]const u8) !void {
    if (p.match(str)) |match| {
        if (expect) |expected_str| {
            return testing.expectEqualStrings(expected_str, match) catch { // check the string matches are the same
                std.debug.print("\x1b[0;31m input: '{s}', expected match: '{s}', but returned: '{s}'\x1b[0m", .{ str, expected_str, match });
                return error.MatchAssertEqualFailed;
            };
        } else {
            std.debug.print("\x1b[0;31m input: '{s}', expected no match, but returned: '{s}'\x1b[0m", .{ str, match });
            return error.MatchAssertEqualFailed;
        }
    } else {
        if (expect) |expected_str| { // expected was not null
            std.debug.print("\x1b[0;31m input: '{s}', expected '{s}', but returned null \x1b[0m", .{ str, expected_str });
            return error.MatchAssertEqualFailed;
        }
    }
    return;
}

test "manual pattern full match" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    p.setInitial(s0);
    p.setFinal(s1);
    p.connect(s0, s1, 'b');
    p.connect(s1, s1, 'b');

    try testing.expect(p.fullmatch("b"));
    try testing.expect(p.fullmatch("bbb"));
    try testing.expect(p.fullmatch("b23b"));
    try testing.expect(!p.fullmatch("a"));
    try testing.expect(!p.fullmatch("icba"));
    try testing.expect(!p.fullmatch(""));
}

test "manual pattern substring match" {
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

test "capture iterator - single character pattern" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    p.setInitial(s0);
    p.setFinal(s1);
    p.connect(s0, s1, 'a');

    var iter = CaptureIterator.init(p, "banana");

    try testing.expectEqualStrings("a", iter.next().?);
    try testing.expectEqualStrings("a", iter.next().?);
    try testing.expectEqualStrings("a", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "capture iterator - pattern with wildcards" {
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

    var iter = CaptureIterator.init(p, "abc__axc__azyc");

    try testing.expectEqualStrings("abc", iter.next().?);
    try testing.expectEqualStrings("axc", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "capture iterator - no matches" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    p.setInitial(s0);
    p.setFinal(s1);
    p.connect(s0, s1, 'x');

    var iter = CaptureIterator.init(p, "abcdef");

    try testing.expect(iter.next() == null);
}

test "capture iterator - empty string" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    p.setInitial(s0);
    p.setFinal(s1);
    p.connect(s0, s1, 'a');

    var iter = CaptureIterator.init(p, "");

    try testing.expect(iter.next() == null);
}

test "capture iterator - overlapping patterns" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    const s2 = p.addState();
    p.setInitial(s0);
    p.setFinal(s2);
    p.connect(s0, s1, 'a');
    p.connect(s1, s2, 'a');

    var iter = CaptureIterator.init(p, "aaaa");

    try testing.expectEqualStrings("aa", iter.next().?);
    try testing.expectEqualStrings("aa", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "capture iterator - complex pattern" {
    // Pattern that matches "ab" followed by any number of 'b's
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    const s2 = p.addState();
    const s3 = p.addState();
    p.setInitial(s0);
    p.setFinal(s3);
    p.connect(s0, s1, 'a');
    p.connect(s1, s2, 'b');
    p.setDefault(s2, s3);
    p.connect(s2, s2, 'b');

    var iter = CaptureIterator.init(p, "ab_abbbb_abbb");

    try testing.expectEqualStrings("ab", iter.next().?);
    try testing.expectEqualStrings("abbbb", iter.next().?);
    try testing.expectEqualStrings("abbb", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "capture iterator - single match at end" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    const s2 = p.addState();
    p.setInitial(s0);
    p.setFinal(s2);
    p.connect(s0, s1, 'e');
    p.connect(s1, s2, 'n');
    p.connect(s2, s2, 'd');

    var iter = CaptureIterator.init(p, "this is the end");

    try testing.expectEqualStrings("end", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "capture iterator - multiple calls after exhaustion" {
    var p = Pattern.init();
    const s0 = p.addState();
    const s1 = p.addState();
    p.setInitial(s0);
    p.setFinal(s1);
    p.connect(s0, s1, 'x');

    var iter = CaptureIterator.init(p, "x");

    try testing.expectEqualStrings("x", iter.next().?);
    try testing.expect(iter.next() == null);
    try testing.expect(iter.next() == null);
    try testing.expect(iter.next() == null);
}
