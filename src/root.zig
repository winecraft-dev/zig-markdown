const std = @import("std");
const evaluate = @import("evaulate.zig");

const LineState = evaluate.LineState;

pub fn convert_markdown(reader: *std.io.Reader, writer: *std.io.Writer) !void {
    var last_s = LineState{ .none = undefined };
    while (reader.takeDelimiterExclusive('\n')) |line| {
        const line_s, const truncated = evaluate.evaluate_line(line);
        print_prefix(last_s, line_s, writer) catch |err| {
            if (err == error.EndLine) {
                last_s = line_s;
                continue;
            } else return err;
        };
        last_s = line_s;

        try writer.print("{s}", .{truncated});
        try print_suffix(line_s, writer);
    } else |err| {
        if (err != error.EndOfStream) {
            return err;
        }
    }
    try print_terminate_list(last_s, writer);
}

fn print_prefix(o: LineState, c: LineState, writer: *std.io.Writer) !void {
    // terminate any previous list
    if (o == .ul and c != .ul) {
        try print_close_lists(o.ul, 0, "ul", writer);
    }
    if (o == .ol and c != .ol) {
        try print_close_lists(o.ol, 0, "ol", writer);
    }
    if (o == .ul and c == .ul and o.ul > c.ul) {
        try print_close_lists(o.ul, c.ul, "ul", writer);
    }
    if (o == .ol and c == .ol and o.ol > c.ol) {
        try print_close_lists(o.ol, c.ol, "ol", writer);
    }
    switch (c) {
        .h1 => try writer.print("<h1>", .{}),
        .h2 => try writer.print("<h2>", .{}),
        .h3 => try writer.print("<h3>", .{}),
        .p => try writer.print("<p>", .{}),
        .hr => {
            try writer.print("<hr/>\n", .{});
            return error.EndLine;
        },
        .ul => |level| {
            if (o != .ul or o.ul < level) {
                try writer.print("<ul>\n", .{});
            }
            try writer.print("<li>", .{});
        },
        .ol => |level| {
            if (o != .ol or o.ol < level) {
                try writer.print("<ol>\n", .{});
            }
            try writer.print("<li>", .{});
        },
        else => return error.EndLine,
    }
}

fn print_close_lists(o: i32, c: i32, tag: []const u8, writer: *std.io.Writer) !void {
    var i = o;
    while (i > c and i > 0) {
        try writer.print("</{s}>\n", .{tag});
        i -= 1;
    }
}

fn print_suffix(c: LineState, writer: *std.io.Writer) !void {
    switch (c) {
        .h1 => try writer.print("</h1>\n", .{}),
        .h2 => try writer.print("</h2>\n", .{}),
        .h3 => try writer.print("</h3>\n", .{}),
        .p => try writer.print("</p>\n", .{}),
        .ol, .ul => try writer.print("</li>\n", .{}),
        else => return,
    }
}

fn print_terminate_list(o: LineState, writer: *std.io.Writer) !void {
    switch (o) {
        .ul => try writer.print("</ul>\n", .{}),
        .ol => try writer.print("</ol>\n", .{}),
        else => {},
    }
}
