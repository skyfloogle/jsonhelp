const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addSharedLibrary("jsonhelp", "src/main.zig", .unversioned);
    lib.linkSystemLibraryName("c");
    // oh my god please tell me there is a nicer way to do this
    lib.setTarget(std.zig.CrossTarget.fromTarget(std.Target{
        .cpu = std.Target.Cpu.baseline(std.Target.Cpu.Arch.i386),
        .os = std.Target.Os.Tag.defaultVersionRange(std.Target.Os.Tag.windows, std.Target.Cpu.Arch.i386),
        .abi = std.Target.Abi.gnu }));
    lib.setBuildMode(mode);
    lib.single_threaded = true;
    if (mode == .ReleaseSmall) {
        lib.strip = true;
    }
    lib.install();
}
