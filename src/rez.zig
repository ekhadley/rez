const std = @import("std");

// Goals
// focus on speed above readability above footprint above safety
// make code nice.
// have fun

// Architecture
// I want the filter patterns to require comptime and the resulting FSM to be comptime too
// Pattern compilation can be accordingly slow since it should only once at comptime.
// This means its worth it to do lots of optimizations in the compilation step

// making the fsm means figuring out how many states we need and which other states each connects to
// i think this involves parsing the filter string expression as a tree
// then make the states so that you only move up or down the branches
// only taking a match if you end at a terminal leaf? something something?

//pub const StateMap = std.AutoHashMap(u8, PatternState);

const MAX_NUM_STATES = 255;
const NUM_CHARS = 255;

// a patternState is a stateless mapping from u8 characters to integers corresponding to the index of the next state in the pattern's array of states.
pub const PatternState = struct {
    const Self = @This();
    dests: [NUM_CHARS]usize,
    initial: bool,
    final: bool,

    pub fn init() Self {
        return .{
            .dests = [_]usize{0} ** NUM_CHARS,
            .initial = false,
            .final = false,
        };
    }

    pub fn read(self: PatternState, char: u8) usize {
        return self.dests[char];
    }

    pub fn connect(self: *Self, char: u8, nextState: usize) void {
        self.dests[char] = nextState;
    }

    pub fn setDefault(self: *Self, defaultState: usize) void {
        for (&self.dests) |*dest| {
            dest.* = defaultState;
        }
    }
};

// a pattern holds all the states in the fsm and is stateful over the course of a single match.
// its methods take in the target string and return various things.
// return values are given as string slices.
pub const Pattern = struct {
    const Self = @This();
    states: [MAX_NUM_STATES]PatternState,
    state: usize,
    n_states: usize,

    pub fn init() Pattern {
        return .{
            .states = [_]PatternState{PatternState.init()} ** MAX_NUM_STATES,
            .state = 0,
            .n_states = 0,
        };
    }
    pub fn getState(self: Self) PatternState {
        return self.states[self.state];
    }
    pub fn read(self: *Self, char: u8) PatternState {
        self.state = self.getState().read(char);
        return self.getState();
    }
    pub fn fullmatch(self: *Self, str: []const u8) bool {
        self.reset();
        for (str) |c| {
            _ = self.read(c);
        }
        return self.getState().final;
    }
    pub fn match(self: *Self, str: []const u8) ?[]const u8 {
        self.reset();
        var started: bool = self.getState().initial;
        var start: usize = 0;
        std.debug.print("starting substring match for input: '{s}'\n", .{str});
        for (str, 0..) |c, i| {
            const cur_state = self.read(c);
            std.debug.print("str[{d}] = '{c}', start: {d}, cur = {d}, final: {}\n", .{ i, c, self.state, start, cur_state.final });
            if (cur_state.initial) {
                started = true;
                start = i + 1;
            }
            if (started and cur_state.final) {
                std.debug.print("match found: str[{d}..{d}+1] = '{s}'\n", .{ start, i + 1, str[start .. i + 1] });
                return str[start .. i + 1];
            }
        }
        std.debug.print("reached end of string with no match\n", .{});
        return null;
    }

    pub fn reset(self: *Pattern) void {
        self.state = 0;
    }
    pub fn addState(self: *Pattern) usize {
        self.states[self.n_states] = PatternState.init();
        self.n_states += 1;
        return self.n_states - 1;
    }
    pub fn connect(self: *Pattern, state1: usize, state2: usize, char: u8) void {
        self.states[state1].connect(char, state2);
    }
    pub fn setFinal(self: *Pattern, idx: usize) void {
        self.states[idx].final = true;
    }
    pub fn setNotFinal(self: *Pattern, idx: usize) void {
        self.states[idx].final = false;
    }
    pub fn setInitial(self: *Pattern, idx: usize) void {
        self.states[idx].initial = true;
    }
    pub fn setNotInitial(self: *Pattern, idx: usize) void {
        self.states[idx].initial = false;
    }
    pub fn setDefault(self: *Pattern, idx: usize, defaultState: usize) void {
        self.states[idx].setDefault(defaultState);
    }
};

// A capture iterator is a helper for iterating over an unknown number of matches.
// each time we call next, it attempts to match again, starting from where the last match ended,
// returning an optional match slice
pub const CaptureIterator = struct {
    const Self = @This();
    pat: Pattern,
    place: usize,
    str: []const u8,

    pub fn init(pat: Pattern, str: []const u8) Self {
        return .{
            .pat = pat,
            .str = str,
            .place = 0,
        };
    }

    pub fn next(self: *Self) ?[]const u8 {
        self.pat.reset();
        var started: bool = self.pat.getState().initial;
        var start: usize = 0;
        std.debug.print("starting substring match for input: '{s}'\n", .{self.str});
        for (self.str[self.place..], 0..) |c, i| {
            const cur_state = self.pat.read(c);
            std.debug.print("str[{d}] = '{c}', place: {d}, start: {d}, cur = {d}, final: {}\n", .{ i, c, self.place, self.pat.state, start, cur_state.final });
            if (cur_state.initial) {
                started = true;
                start = i + 1;
            }
            if (started and cur_state.final) {
                std.debug.print("match found: str[{d}..{d}+1] = '{s}'\n", .{ start, i + 1, self.str[start + self.place .. self.place + i + 1] });
                const match = self.str[start + self.place .. self.place + i + 1];
                self.place += i + 1;
                return match;
            }
        }
        self.place = self.str.len;
        std.debug.print("reached end of string with no match\n", .{});
        return null;
    }
};
