const std = @import("std");
const shared = @import("shared.zig");

fn toDelphiString(s: []const u8) ?[*:0]u8 {
    var out: ?[*:0]u8 = null;
    const func: u32 = 0x404718;
    _ = asm volatile ("call *%%ebx"
        :
        : [func] "{ebx}" (func),
          [out] "{eax}" (&out),
          [s] "{edx}" (s.ptr),
          [l] "{ecx}" (s.len),
        : "eax", "edx", "ecx"
    );
    return out;
}

fn funcalloc(file: *shared.CExtensionFile, count: usize) void {
    const func: u32 = 0x4759a4;
    return asm volatile ("call *%%ecx"
        :
        : [func] "{ecx}" (func),
          [file] "{eax}" (file),
          [count] "{edx}" (count),
        : "eax", "edx", "ecx"
    );
}

fn constalloc(file: *shared.CExtensionFile, count: usize) void {
    const func: u32 = 0x475a44;
    return asm volatile ("call *%%ecx"
        :
        : [func] "{ecx}" (func),
          [file] "{eax}" (file),
          [count] "{edx}" (count),
        : "eax", "edx", "ecx"
    );
}

fn usesalloc(package: *shared.CExtensionPackage, count: usize) void {
    const func: u32 = 0x475f3c;
    return asm volatile ("call *%%ecx"
        :
        : [func] "{ecx}" (func),
          [file] "{eax}" (package),
          [count] "{edx}" (count),
        : "eax", "edx", "ecx"
    );
}

fn filealloc(package: *shared.CExtensionPackage, count: usize) void {
    const func: u32 = 0x475fb8;
    return asm volatile ("call *%%ecx"
        :
        : [func] "{ecx}" (func),
          [file] "{eax}" (package),
          [count] "{edx}" (count),
        : "eax", "edx", "ecx"
    );
}

fn constcnv(dst: *shared.CExtensionConstant, src: shared.JConstant) void {
    dst.s_name = toDelphiString(src.name);
    dst.s_value = toDelphiString(src.value);
    dst.s_hidden = src.hidden;
}

fn funccnv(dst: *shared.CExtensionFunction, src: shared.JFunction) void {
    dst.s_name = toDelphiString(src.name);
    dst.s_extname = toDelphiString(src.extname);
    dst.s_kind = src.calltype;
    dst.s_helpline = toDelphiString(src.helpline);
    dst.s_hidden = src.hidden;
    if (src.argtypes != null) {
        const argtypes = src.argtypes.?;
        dst.s_argcount = @intCast(i32, argtypes.len);
        var i: usize = 0;
        while (i < argtypes.len) {
            dst.s_argtype[i] = argtypes[i];
            i += 1;
        }
    } else {
        dst.s_argcount = -1;
    }
    dst.s_returntype = src.returntype;
}

fn filecnv(dst: *shared.CExtensionFile, src: shared.JFile) void {
    dst.s_filename = toDelphiString(src.filename);
    dst.s_origname = toDelphiString(src.origname);
    dst.s_kind = src.kind;
    dst.s_init = toDelphiString(src.init);
    dst.s_final = toDelphiString(src.final);
    funcalloc(dst, src.functions.len);
    var i: usize = 0;
    while (i < src.functions.len) {
        funccnv(dst.s_functions[i], src.functions[i]);
        i += 1;
    }
    constalloc(dst, src.constants.len);
    i = 0;
    while (i < src.constants.len) {
        constcnv(dst.s_constants[i], src.constants[i]);
        i += 1;
    }
}

fn packcnv(dst: *shared.CExtensionPackage, src: shared.JPackage) void {
    dst.s_name = toDelphiString(src.name);
    dst.s_folder = toDelphiString(src.folder);
    dst.s_version = toDelphiString(src.version);
    dst.s_author = toDelphiString(src.author);
    dst.s_date = toDelphiString(src.date);
    dst.s_license = toDelphiString(src.license);
    dst.s_description = toDelphiString(src.description);
    dst.s_helpfile = toDelphiString(src.helpfile);
    dst.s_hidden = src.hidden;
    usesalloc(dst, src.dependencies.len);
    var i: usize = 0;
    while (i < src.dependencies.len) {
        dst.s_uses[i] = toDelphiString(src.dependencies[i]);
        i += 1;
    }
    filealloc(dst, src.files.len);
    i = 0;
    while (i < src.files.len) {
        filecnv(dst.s_includes[i], src.files[i]);
        i += 1;
    }
}

pub fn load(package: *shared.CExtensionPackage, fname: [*:0]const u8) callconv(.Stdcall) u32 {
    // use original load function if loading a .ged
    const len = shared.strlen(fname);
    if (len != 0 and fname[len - 4] == '.' and fname[len - 3] == 'g' and fname[len - 2] == 'e' and fname[len - 1] == 'd') {
        const loadFunc: u32 = 0x47644c;
        return asm volatile ("call *%%ecx"
            : [ret] "={eax}" (-> u32),
            : [func] "{ecx}" (loadFunc),
              [package] "{eax}" (package),
              [fname] "{edx}" (fname),
            : "eax", "edx", "ecx"
        );
    }
    // clear existing package data
    const clearPackage: u32 = 0x47609c;
    _ = asm volatile ("call *%%ecx"
        :
        : [func] "{ecx}" (clearPackage),
          [package] "{eax}" (package),
        : "eax", "edx", "ecx"
    );
    // create allocator
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();
    // open and read file
    var file = std.fs.openFileAbsoluteZ(fname, .{}) catch return 0;
    defer file.close();
    var json = file.readToEndAlloc(alloc.allocator(), 0x1fffffff) catch return 0;
    // read json
    var stream = std.json.TokenStream.init(json);
    @setEvalBranchQuota(99999); // apparently 1000 wasn't enough for the json parsing code
    const parsedData = std.json.parse(shared.JPackage, &stream, .{ .allocator = alloc.allocator() }) catch return 0;
    defer std.json.parseFree(shared.JPackage, parsedData, .{ .allocator = alloc.allocator() });
    // convert
    packcnv(package, parsedData);
    return 1;
}
