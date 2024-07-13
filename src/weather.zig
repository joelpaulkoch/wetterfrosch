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

pub const we =
    \\Mannheim
    \\
    \\     \  /       Partly cloudy
    \\   _ /"".-.     29 °C          
    \\     \_(   ).   → 4 km/h       
    \\     /(___(__)  10 km          
    \\                0.0 mm         
    \\                        ┌─────────────┐                        
    \\┌───────────────────────┤  Mon 19 Jun ├───────────────────────┐
    \\│             Noon      └──────┬──────┘      Night            │
    \\├──────────────────────────────┼──────────────────────────────┤
    \\│     \   /     Sunny          │     \   /     Sunny          │
    \\│      .-.      +30(31) °C     │      .-.      +24(25) °C     │
    \\│   ― (   ) ―   → 12-14 km/h   │   ― (   ) ―   ↙ 6-13 km/h    │
    \\│      `-’      10 km          │      `-’      10 km          │
    \\│     /   \     0.0 mm | 0%    │     /   \     0.0 mm | 0%    │
    \\└──────────────────────────────┴──────────────────────────────┘
;
pub const we2 =
    \\Mannheim
    \\
    \\     \  /       Partly cloudy
    \\   _ /"".-.     29 °C          
    \\     \_(   ).   → 4 km/h       
    \\     /(___(__)  10 km          
    \\                0.0 mm      
    \\                        
    \\┌───────────────────────
    \\│             Noon      
;
