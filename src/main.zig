const std = @import("std");
const hhctrl = @import("hhctrl.zig");
const save = @import("save.zig");
const load = @import("load.zig");

comptime {
    @export(hhctrl.HtmlHelpA, .{ .name = "HtmlHelpA", .linkage = .Strong });
}

fn savewrap() callconv(.Naked) void {
    // pop return address, push args, push return address, then jmp to save() (obeying stdcall)
    return asm volatile (
        \\pop %%ecx
        \\push %%edx
        \\push %%eax
        \\push %%ecx
        \\mov %[save], %%eax
        \\jmp *%%eax
        :
        : [save] "s" (save.save),
    );
}

fn loadwrap() callconv(.Naked) void {
    // pop return address, push args, push return address, then jmp to load() (obeying stdcall)
    return asm volatile (
        \\pop %%ecx
        \\push %%edx
        \\push %%eax
        \\push %%ecx
        \\mov %[load], %%eax
        \\jmp *%%eax
        :
        : [load] "s" (load.load),
    );
}

fn renameToGej() callconv(.Naked) void {
    // call ChangeFileExt instead of @LStrAsg (switching arguments around as needed)
    // note that a ret instruction is inserted automatically
    return asm volatile (
        \\.section .data
        \\.int -1
        \\.int 4
        \\1: .asciz ".gej"
        \\.section .text
        \\mov %%eax, %%ecx
        \\mov %%edx, %%eax
        \\mov $1b, %%edx
        \\push %%ebx
        \\mov $0x408c68, %%ebx
        \\call *%%ebx
        \\pop %%ebx
    );
}

// ffi
extern "kernel32" fn WriteProcessMemory(
    hProcess: std.os.windows.HANDLE,
    lpBaseAddress: usize,
    lpBuffer: *const u32,
    nSize: usize,
    lpNumberOfBytesWritten: usize,
) callconv(.Stdcall) void;
extern "kernel32" fn GetCurrentProcess() callconv(.Stdcall) std.os.windows.HANDLE;

pub fn DllMain(_hInstance: std.os.windows.HINSTANCE, ul_reason_for_call: std.os.windows.DWORD, _lpReserved: std.os.windows.LPVOID) callconv(.Stdcall) std.os.windows.BOOL {
    // discard arguments
    _ = _hInstance;
    _ = _lpReserved;
    if (ul_reason_for_call == 1) {
        // apply patches
        const proc = GetCurrentProcess();
        const save_offset = @ptrToInt(savewrap) - 0x478706;
        WriteProcessMemory(proc, 0x478702, &save_offset, 4, 0);
        const load_offset = @ptrToInt(loadwrap) - 0x4786a6;
        WriteProcessMemory(proc, 0x4786a2, &load_offset, 4, 0);
        const rename_offset = @ptrToInt(renameToGej) - 0x47a1ee;
        WriteProcessMemory(proc, 0x47a1ea, &rename_offset, 4, 0);
    }
    return 1;
}
