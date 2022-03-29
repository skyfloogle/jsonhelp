pub const CExtensionConstant = extern struct {
    vmt: u32,
    s_name: ?[*:0]u8,
    s_value: ?[*:0]u8,
    s_hidden: bool,
};

pub const CExtensionFunction = extern struct {
    vmt: u32,
    s_name: ?[*:0]u8,
    s_extname: ?[*:0]u8,
    s_kind: i32,
    s_helpline: ?[*:0]u8,
    s_hidden: bool,
    s_argcount: i32,
    s_argtype: [17]i32,
    s_returntype: i32,
};

pub const CExtensionFile = extern struct {
    vmt: u32,
    s_filename: ?[*:0]u8,
    s_origname: ?[*:0]u8,
    s_kind: i32,
    s_init: ?[*:0]u8,
    s_final: ?[*:0]u8,
    s_functions: [*]*CExtensionFunction,
    s_cfunctions: u32,
    s_constants: [*]*CExtensionConstant,
    s_cconstants: u32,
};

pub const CExtensionPackage = extern struct {
    vmt: u32,
    s_name: ?[*:0]u8,
    s_folder: ?[*:0]u8,
    s_version: ?[*:0]u8,
    s_author: ?[*:0]u8,
    s_date: ?[*:0]u8,
    s_license: ?[*:0]u8,
    s_description: ?[*:0]u8,
    s_helpfile: ?[*:0]u8,
    s_hidden: bool,
    s_uses: [*]?[*:0]u8,
    s_cuses: u32,
    s_includes: [*]*CExtensionFile,
    s_cincludes: u32,
};

pub const JConstant = struct {
    name: []const u8,
    value: []const u8,
    hidden: bool,
};

pub const JFunction = struct {
    name: []const u8,
    extname: []const u8,
    calltype: i32,
    helpline: []const u8,
    hidden: bool,
    argtypes: ?[]const i32,
    returntype: i32,
};

pub const JFile = struct {
    filename: []const u8,
    origname: []const u8,
    kind: i32,
    init: []const u8,
    final: []const u8,
    functions: []JFunction,
    constants: []JConstant,
};

pub const JPackage = struct {
    name: []const u8,
    folder: []const u8,
    version: []const u8,
    author: []const u8,
    date: []const u8,
    license: []const u8,
    description: []const u8,
    helpfile: []const u8,
    hidden: bool,
    dependencies: [][]const u8,
    files: []JFile,
};

pub fn strlen(s: [*:0]const u8) usize {
    // delphi strings have length right before text
    // int cast is needed to cope with supposed alignment changes
    return @intToPtr(*const usize, @ptrToInt(s) - 4).*;
}
