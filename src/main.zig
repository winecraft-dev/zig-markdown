const std = @import("std");
const eql = std.mem.eql;
const markdown = @import("markdown");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const file_name = try readFileName(allocator);
    defer allocator.free(file_name);

    var file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    const buf: []u8 = try allocator.alloc(u8, 1024);
    defer allocator.free(buf);
    var file_reader = file.reader(buf);
    var stdout = std.fs.File.stdout().writer(undefined);

    try markdown.convert_markdown(&file_reader.interface, &stdout.interface);
}

pub fn readFileName(allocator: std.mem.Allocator) ![]u8 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        return error.MissingArg;
    }

    const file_name = try allocator.alloc(u8, args[1].len);
    std.mem.copyForwards(u8, file_name, args[1]);

    return file_name;
}

const List = enum { none, unordered_list, ordered_list };
const ListState = union(List) { none: void, unordered_list: void, ordered_list: i32 };
