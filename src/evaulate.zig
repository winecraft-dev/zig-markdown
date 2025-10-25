const std = @import("std");
const markdown = @import("root.zig");

pub const LineType = enum { none, h1, h2, h3, hr, block_quote, p, ul, ol };
pub const LineState = union(LineType) { none, h1, h2, h3, hr, block_quote, p, ul: i32, ol: i32 };
pub const StyleState = struct {
    code: bool = false,
    italic: bool = false,
    bold: bool = false,
};
pub const LinkState = enum { image_text, link_text, image_url, link_url };
const ListResult = struct {
    level: i32,
    trimmed: []u8,
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
    } else if (line.len == 0) {
        return .{ .none, undefined };
    } else if (check_ol(line)) |res| {
        return .{ LineState{ .ol = res.level }, res.trimmed };
    } else if (check_ul(line)) |res| {
        return .{ LineState{ .ul = res.level }, res.trimmed };
    }
    return .{ .p, line };
}

fn check_ol(line: []u8) ?ListResult {
    var spaces: i32 = 0;
    var numbers = false;
    var period = false;
    for (line, 0..) |c, i| {
        if (c == 32 and !period) {
            spaces += 1;
        } else if (c >= 48 and c <= 57) {
            numbers = true;
        } else if (c == 46 and numbers) {
            period = true;
        } else if (c == 32 and period) {
            return .{
                .level = 1 + @divFloor(spaces, 4),
                .trimmed = line[i + 1 ..],
            };
        } else break;
    }
    return null;
}

fn check_ul(line: []u8) ?ListResult {
    var spaces: i32 = 0;
    var hyphen = false;
    for (line, 0..) |c, i| {
        if (c == 32 and !hyphen) {
            spaces += 1;
        } else if (c == 45) {
            hyphen = true;
        } else if (c == 32 and hyphen) {
            return .{
                .level = 1 + @divFloor(spaces, 4),
                .trimmed = line[i + 1 ..],
            };
        } else break;
    }
    return null;
}
