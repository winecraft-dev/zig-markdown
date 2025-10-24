const std = @import("std");
const evaluate = @import("evaulate.zig");

const LineState = evaluate.LineState;

pub fn convert_markdown(reader: *std.io.Reader, writer: *std.io.Writer) !void {
    var last_s = LineState.none;
    while (reader.takeDelimiterExclusive('\n')) |line| {
        const line_s, const truncated = evaluate.evaluate_line(line);
        print_prefix(last_s, line_s, writer) catch |err| {
            if (err == error.EndLine) {
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
        try writer.print("</ul>\n", .{});
    }
    if (o == .ol and c != .ol) {
        try writer.print("</ol>\n", .{});
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
        .ul => {
            if (o != .ul) {
                try writer.print("<ul>\n", .{});
            }
            try writer.print("<li>", .{});
        },
        .ol => {
            if (o != .ol) {
                try writer.print("<ol>\n", .{});
            }
            try writer.print("<li>", .{});
        },
        else => return error.EndLine,
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
