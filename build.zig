const std = @import("std");

// harb -- the declared machine. One static binary, every role: the CLI on
// the host, PID 1 on the machine. Zero dependencies, zero network: the
// Zig standard library is the whole toolchain.
//
//   zig build                      -> zig-out/bin/harb (host)
//   zig build test                 -> the unit tests (the mechanism and its negatives)
//   zig build court                -> the fixture court (declarative/machine/fixtures.json)
//   zig build cross                -> zig-out/cross/<triple>/harb for the machine targets
//
// `cross` exists because init.zig is comptime-gated on Linux and Zig
// analyses only the taken side of a comptime branch: a Windows build
// proves nothing about the init. The gate is the Linux build.

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "harb",
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
    b.step("run", "Run harb with the given arguments").dependOn(&run_cmd.step);

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
    const court_step = b.step("court", "Judge the machine, fleet and pack grammars by their pinned fixtures, the guided tour, and the pages");
    court_step.dependOn(&court_cmd.step);

    // the fleet court: the checks no single machine can be wrong about
    const fleet_cmd = b.addRunArtifact(exe);
    fleet_cmd.addArg("court");
    fleet_cmd.addArg("--fleet");
    fleet_cmd.addArg("declarative/fleet/fixtures.json");
    fleet_cmd.setCwd(b.path("."));
    court_step.dependOn(&fleet_cmd.step);

    // the pack court: what a solution asks, placed on a machine that grants
    // it -- the refusals no pack alone and no machine alone can be wrong
    // about, each at the file and the line that wrote it (PLC-1)
    const pack_cmd = b.addRunArtifact(exe);
    pack_cmd.addArg("court");
    pack_cmd.addArg("--pack");
    pack_cmd.addArg("declarative/pack/fixtures.json");
    pack_cmd.setCwd(b.path("."));
    court_step.dependOn(&pack_cmd.step);

    // the guided tour is judged too: a lesson that points at a machine
    // somebody renamed is a tutorial that lies, and this turns the court
    // red in the commit that made it (LRN-1)
    const learn_cmd = b.addRunArtifact(exe);
    learn_cmd.addArg("learn");
    learn_cmd.addArg("--check");
    learn_cmd.setCwd(b.path("."));
    court_step.dependOn(&learn_cmd.step);

    // and so are the pages: a code line the reader must scroll sideways to
    // read, or a machine shown in full that the court would refuse, turns
    // the court red in the commit that wrote it (DOC-1)
    const docs_cmd = b.addRunArtifact(exe);
    docs_cmd.addArg("docs");
    docs_cmd.addArg("--check");
    docs_cmd.setCwd(b.path("."));
    court_step.dependOn(&docs_cmd.step);

    // the machine targets: static, musl, one flag each
    const cross = b.step("cross", "Build harb for the hosted-profile machine targets (static musl)");
    const triples = [_][]const u8{ "x86_64-linux-musl", "aarch64-linux-musl" };
    for (triples) |triple| {
        const q = std.Target.Query.parse(.{ .arch_os_abi = triple }) catch unreachable;
        const t = b.resolveTargetQuery(q);
        const cexe = b.addExecutable(.{
            .name = "harb",
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
