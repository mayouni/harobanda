const std = @import("std");

// stzos -- the declared machine. One static binary, every role: the CLI on
// the host, PID 1 on the machine. Zero dependencies, zero network: the
// Zig standard library is the whole toolchain.
//
//   zig build                      -> zig-out/bin/stzos (host)
//   zig build test                 -> the unit tests (the mechanism and its negatives)
//   zig build court                -> the fixture court (declarative/machine/fixtures.json)
//   zig build cross                -> zig-out/cross/<triple>/stzos for the machine targets
//
// `cross` exists because init.zig is comptime-gated on Linux and Zig
// analyses only the taken side of a comptime branch: a Windows build
// proves nothing about the init. The gate is the Linux build.

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "stzos",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Run stzos with the given arguments").dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.step("test", "Run the unit tests").dependOn(&b.addRunArtifact(tests).step);

    const court_cmd = b.addRunArtifact(exe);
    court_cmd.addArg("court");
    court_cmd.addArg("declarative/machine/fixtures.json");
    court_cmd.setCwd(b.path("."));
    b.step("court", "Judge the machine grammar by its pinned fixtures").dependOn(&court_cmd.step);

    // the machine targets: static, musl, one flag each
    const cross = b.step("cross", "Build stzos for the hosted-profile machine targets (static musl)");
    const triples = [_][]const u8{ "x86_64-linux-musl", "aarch64-linux-musl" };
    for (triples) |triple| {
        const q = std.Target.Query.parse(.{ .arch_os_abi = triple }) catch unreachable;
        const t = b.resolveTargetQuery(q);
        const cexe = b.addExecutable(.{
            .name = "stzos",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = t,
                .optimize = .ReleaseSafe,
            }),
        });
        cexe.linkage = .static;
        const inst = b.addInstallArtifact(cexe, .{ .dest_dir = .{ .override = .{ .custom = b.fmt("cross/{s}", .{triple}) } } });
        cross.dependOn(&inst.step);
    }
}
