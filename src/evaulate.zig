const std = @import("std");
const markdown = @import("root.zig");

pub const LineState = enum { none, h1, h2, h3, hr, block_quote, p, ul, ol };
pub const StyleState = struct {
    bold: bool = false,
    italic: bool = false,
    code: bool = false,
};

pub fn evaluate_line(line: []u8) struct { LineState, []u8 } {
    if (line.len >= 4 and std.mem.eql(u8, line[0..4], "### ")) {
        return .{ .h3, line[4..] };
    } else if (line.len >= 3 and std.mem.eql(u8, line[0..3], "## ")) {
        return .{ .h2, line[3..] };
    } else if (line.len >= 2 and std.mem.eql(u8, line[0..2], "# ")) {
        return .{ .h1, line[2..] };
    } else if (line.len >= 3 and std.mem.eql(u8, line[0..3], "---")) {
        return .{ .hr, undefined };
    } else if (line.len >= 2 and std.mem.eql(u8, line[0..2], "> ")) {
        return .{ .block_quote, line[2..] };
    } else if (line.len >= 2 and std.mem.eql(u8, line[0..2], "- ")) {
        return .{ .ul, line[2..] };
    } else if (line.len == 0) {
        return .{ .none, undefined };
    } else if (line.len >= 3) {
        var numbers = false;
        var period = false;
        for (line, 0..) |c, i| {
            if (c >= 48 and c <= 57) {
                numbers = true;
            } else if (c == 46 and numbers) {
                period = true;
            } else if (c == 32 and period) {
                return .{ .ol, line[i + 1 ..] };
            } else {
                break;
            }
        }
    }

    return .{ .p, line };
}
