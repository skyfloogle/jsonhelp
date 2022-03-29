const std = @import("std");
const shared = @import("shared.zig");

fn strcnv(s_: ?[*:0]const u8) []const u8 {
    const s = s_ orelse return "";
    return s[0..shared.strlen(s)];
}

fn constcnv(c: *const shared.CExtensionConstant) shared.JConstant {
    return shared.JConstant{
        .name = strcnv(c.s_name),
        .value = strcnv(c.s_value),
        .hidden = c.s_hidden,
    };
}

fn funccnv(f: *const shared.CExtensionFunction) shared.JFunction {
    return shared.JFunction{
        .name = strcnv(f.s_name),
        .extname = strcnv(f.s_extname),
        .calltype = f.s_kind,
        .helpline = strcnv(f.s_helpline),
        .hidden = f.s_hidden,
        .argtypes = if (f.s_argcount >= 0) f.s_argtype[0..@intCast(usize, f.s_argcount)] else null,
        .returntype = f.s_returntype,
    };
}

fn filecnv(alloc: std.mem.Allocator, f: *const shared.CExtensionFile) !shared.JFile {
    var constants = std.ArrayList(shared.JConstant).init(alloc);
    for (f.s_constants[0..f.s_cconstants]) |c| {
        try constants.append(constcnv(c));
    }
    var functions = std.ArrayList(shared.JFunction).init(alloc);
    for (f.s_functions[0..f.s_cfunctions]) |fu| {
        try functions.append(funccnv(fu));
    }
    return shared.JFile{
        .filename = strcnv(f.s_filename),
        .origname = strcnv(f.s_origname),
        .kind = f.s_kind,
        .init = strcnv(f.s_init),
        .final = strcnv(f.s_final),
        .functions = functions.items,
        .constants = constants.items,
    };
}

fn packcnv(alloc: std.mem.Allocator, p: *const shared.CExtensionPackage) !shared.JPackage {
    var files = std.ArrayList(shared.JFile).init(alloc);
    for (p.s_includes[0..p.s_cincludes]) |f| {
        try files.append(try filecnv(alloc, f));
    }
    var dependencies = std.ArrayList([]const u8).init(alloc);
    for (p.s_uses[0..p.s_cuses]) |u| {
        try dependencies.append(strcnv(u));
    }
    return shared.JPackage{
        .name = strcnv(p.s_name),
        .folder = strcnv(p.s_folder),
        .version = strcnv(p.s_version),
        .author = strcnv(p.s_author),
        .date = strcnv(p.s_date),
        .license = strcnv(p.s_license),
        .description = strcnv(p.s_description),
        .helpfile = strcnv(p.s_helpfile),
        .hidden = p.s_hidden,
        .dependencies = dependencies.items,
        .files = files.items,
    };
}

pub fn save(package: *shared.CExtensionPackage, fname: [*:0]const u8) callconv(.Stdcall) u32 {
    // create allocator
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();
    // open file
    var file = std.fs.createFileAbsoluteZ(fname, .{}) catch return 0;
    defer file.close();
    // buffered writer
    var stream = std.io.bufferedWriter(file.writer());
    // stringify
    std.json.stringify(packcnv(alloc.allocator(), package) catch return 0, std.json.StringifyOptions{ .whitespace = std.json.StringifyOptions.Whitespace{ .indent = .Tab } }, stream.writer()) catch return 0;
    // flush buffered writer
    stream.flush() catch return 0;
    return 1;
}
