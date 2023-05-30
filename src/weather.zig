const std = @import("std");

pub fn weather() !void {
    //var memBuffer: [1000]u8 = undefined;
    //var fba = std.heap.FixedBufferAllocator.init(&memBuffer);
    //const allocator = fba.allocator();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse("https://wttr.in/Mannheim?1FAnq") catch unreachable;
    //const headers = std.http.Client.Request.Headers {};
    //const options = std.http.Client.Options{ .header_strategy = .{.dynamic = 64 * 1024}};
    var req = try client.request(uri, .{}, .{});
    defer req.deinit();

    try req.do();

    var buffer: [2048]u8 = undefined;
    const result = req.readAll(&buffer);

    // std.debug.print("{s}", .{buffer});
    if (result) |bytes| {
        std.debug.print("Read {d} bytes\n{s}", .{ bytes, buffer });
    } else |err| {
        std.debug.print("{}", .{err});
    }
}
