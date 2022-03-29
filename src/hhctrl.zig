const std = @import("std");

// ffi
extern "kernel32" fn GetProcAddress(hModule: std.os.windows.HMODULE, lpProcName: [*:0]const u8) callconv(.Stdcall) u32;

const HtmlHelpAPtr_t = fn (u32, u32, u32, u32, u32) callconv(.Stdcall) u32;

// pointer to the real HtmlHelpA function
// can't really null this, so initialize to the shim
var HtmlHelpAPtr: HtmlHelpAPtr_t = HtmlHelpA_;

fn HtmlHelpA_(a: u32, b: u32, c: u32, d: u32, e: u32) callconv(.Stdcall) u32 {
    // if we haven't already, load the real dll and function address
    if (HtmlHelpAPtr == HtmlHelpA_) {
        const lib = std.os.windows.LoadLibraryW(std.unicode.utf8ToUtf16LeStringLiteral("HHCTRL.OCX")) catch return 0;
        HtmlHelpAPtr = @intToPtr(HtmlHelpAPtr_t, GetProcAddress(lib, "HtmlHelpA"));
    }
    // this compiles to literally a jmp and i find this incredibly satisfying
    return HtmlHelpAPtr(a, b, c, d, e);
}

// zig doesn't support exporting stdcall without name mangling, so a non-stdcall helper is needed
pub fn HtmlHelpA() callconv(.Naked) void {
    asm volatile ("jmp *%[func]"
        :
        : [func] "{eax}" (HtmlHelpA_),
    );
}
