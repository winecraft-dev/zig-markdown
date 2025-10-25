const std = @import("std");
const evaluate = @import("evaulate.zig");

const LineState = evaluate.LineState;
const StyleState = evaluate.StyleState;
const LinkState = evaluate.LinkState;

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

        try print_line(truncated, writer);
        try print_suffix(line_s, writer);
    } else |err| {
        if (err != error.EndOfStream) {
            return err;
        }
    }
    try print_terminate_list(last_s, writer);
}

fn print_line(line: []u8, writer: *std.io.Writer) !void {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    var url = try std.ArrayList(u8).initCapacity(allocator, 32);
    var title = try std.ArrayList(u8).initCapacity(allocator, 32);
    defer url.deinit(allocator);
    defer title.deinit(allocator);

    var style = StyleState{};
    var link: ?LinkState = null;
    var exclamation = false;
    var asterisks: i32 = 0;
    for (line) |c| {
        if (c == '*') {
            asterisks += 1;
        }
        // else if (c == '`') {
        //     if (!style.code) {
        //         try writer.print("<code>", .{});
        //     } else {
        //         try writer.print("</code>", .{});
        //     }
        //     style.code = !style.code;
        // }
        else if (c == '!') {
            exclamation = true;
        } else if (c == '[' and exclamation) {
            link = .image_text;
            exclamation = false;
        } else if (c == '[') {
            link = .link_text;
        } else if (c == ']' and (link == .image_text or link == .link_text)) {
            //
        } else if (c == '(' and link == .image_text) {
            link = .image_url;
        } else if (c == '(' and link == .link_text) {
            link = .link_url;
        } else if (c == ')' and link == .image_url) {
            try writer.print("<img src=\"{s}\" alt=\"{s}\">", .{ url.items, title.items });
            title.clearAndFree(allocator);
            url.clearAndFree(allocator);
            link = null;
        } else if (c == ')' and link == .link_url) {
            try writer.print("<a href=\"{s}\">{s}</a>", .{ url.items, title.items });
            title.clearAndFree(allocator);
            url.clearAndFree(allocator);
            link = null;
        } else if (link == .image_text or link == .link_text) {
            try title.append(allocator, c);
        } else if (link == .image_url or link == .link_url) {
            try url.append(allocator, c);
        } else if (asterisks == 2) {
            if (!style.bold) {
                try writer.print("<b>{c}", .{c});
                style.bold = true;
            } else {
                try writer.print("</b>{c}", .{c});
                style.bold = false;
            }
            asterisks = 0;
        } else if (asterisks == 1) {
            if (!style.italic) {
                try writer.print("<i>{c}", .{c});
                style.italic = true;
            } else {
                try writer.print("</i>{c}", .{c});
                style.italic = false;
            }
            asterisks = 0;
        } else if (asterisks >= 3) {
            if (!(style.italic and style.bold)) {
                try writer.print("<b><i>{c}", .{c});
                style.italic = true;
                style.bold = true;
            } else {
                try writer.print("</i></b>{c}", .{c});
                style.italic = false;
                style.bold = false;
            }
            asterisks = 0;
        } else {
            try writer.printAsciiChar(c, .{});
        }
    }
    if (style.bold) {
        try writer.print("</b>", .{});
    }
    if (style.italic) {
        try writer.print("</i>", .{});
    }
    if (style.code) {
        try writer.print("</code", .{});
    }
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
