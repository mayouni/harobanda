//! `stzos learn` -- the guided tour of what this machine can do and why
//! (LRN-1).
//!
//! ## Why it lives in the binary
//!
//! Everything here is judged by something that would notice if it drifted:
//! the grammar by its fixtures, the boot by its own expectation, the
//! transcript by its pin. A tutorial written as prose in a document has
//! no such judge -- it says "run this and you will see that" and nothing
//! checks that the file still exists, that the verb is still spelled that
//! way, or that the line it tells you to look for is still printed.
//!
//! So the curriculum is a table beside the verbs it teaches, and `stzos
//! learn --check` walks every path a lesson names and fails if one is
//! gone. `zig build court` runs that check, which means a lesson pointing
//! at a machine somebody renamed turns the court red in the same commit.
//!
//! ## The shape of a lesson
//!
//! Six fields, and the fourth is the one that matters:
//!
//!   the question   what you do not yet know
//!   run            one command, copy-pasteable
//!   look for       the exact lines that answer it
//!   BREAK IT       a change you make so the machine convicts you
//!   the law        the sentence it paid for, verbatim from the doctrine
//!   the story      where the full account lives
//!
//! "Break it" is the point. A guarantee you have only seen SUCCEED is a
//! claim; a guarantee you have watched refuse you is evidence. That is
//! the same argument the IDENTITY seat made about a signature nobody
//! tried to break, and it is why every lesson here asks you to try.

const std = @import("std");

pub const Lesson = struct {
    act: []const u8,
    title: []const u8,
    question: []const u8,
    run: []const u8,
    /// true when `run` is a verb of this same binary, so `--run` can
    /// spawn it. The boots are WSL scripts and are never spawned from
    /// here: the machine that runs them is not the machine you type on.
    runnable: bool = false,
    look: []const []const u8,
    breakit: []const u8,
    law: []const u8,
    story: []const u8,
    /// paths this lesson names, checked by `--check` so a lesson cannot
    /// outlive what it points at
    needs: []const []const u8 = &.{},
};

pub const lessons = [_]Lesson{
    // ---- I. the declaration -------------------------------------------
    .{
        .act = "I. THE DECLARATION",
        .title = "A machine is a text file, and it is judged before anything runs",
        .question = "What IS a machine here, before any of it exists?",
        .run = "stzos check machines/qemu_hello.machine",
        .runnable = true,
        .look = &.{
            "machine qemu_hello -- hosted / x86_64 / kernel linux -- ... judged, no refusal",
            "Nothing was built, mounted or started. A file was read and a verdict given,",
            "and that verdict is the whole of what this command does.",
        },
        .breakit = "Add a service whose RUN is [\"sh\", \"-c\", \"echo hi\"] and check again. It is refused BY NAME: there is no shell on the boot path, and the grammar will not let a declaration even ask for one.",
        .law = "Closed grammars have no host escape.",
        .story = "declarative/machine/GRAMMAR.md",
        .needs = &.{ "machines/qemu_hello.machine", "declarative/machine/GRAMMAR.md" },
    },
    .{
        .act = "I. THE DECLARATION",
        .title = "The declaration becomes a plan, and nothing else",
        .question = "What does the machine intend to do, in order, before it does any of it?",
        .run = "stzos plan machines/qemu_confine.machine",
        .runnable = true,
        .look = &.{
            "every step in the order it happens: the profile's implicit proc, sys and dev,",
            "then each declared mount, each capability granted or refused, then the worlds",
            "with their NEEDS, their budgets and -- since SEE-1 -- which storage each keeps:",
            "  start ledger ... needs [process, network, filesystem] -- sees [data]",
        },
        .breakit = "Make two services name each other in AFTER. The plan is refused for a cycle rather than printed in some arbitrary order.",
        .law = "The plan is derived from the declaration; the act is PID 1's.",
        .story = "doc/ARCHITECTURE.md",
        .needs = &.{ "machines/qemu_confine.machine", "doc/ARCHITECTURE.md" },
    },
    .{
        .act = "I. THE DECLARATION",
        .title = "The grammar is closed, and every refusal names its reason",
        .question = "If the language will not admit something, how do you know it refused for the RIGHT reason?",
        .run = "zig build court -j2",
        .look = &.{
            "107/107 -- 23 accepts, 84 rejects, 0 failures      (the machine grammar)",
            "22/22 -- 4 accepts, 18 rejects, 0 failures         (the fleet grammar)",
            "Eighty-four of those cases are things the language REFUSES, and each one",
            "carries the fragment its refusal must contain -- so refusing for the wrong",
            "reason fails as loudly as not refusing at all.",
        },
        .breakit = "Open declarative/machine/fixtures.json, pick any reject, and change its \"refusal\" to a phrase the parser would never say. The court names the case, what it expected and what it got.",
        .law = "Fixtures are the judge. Every reject carries the fragment its refusal must contain.",
        .story = "declarative/machine/PINNING.md",
        .needs = &.{ "declarative/machine/fixtures.json", "declarative/machine/PINNING.md" },
    },

    // ---- II. the boot --------------------------------------------------
    .{
        .act = "II. THE BOOT",
        .title = "The machine boots, and narrates every step as it takes it",
        .question = "What does a declared machine actually DO when it starts?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_hello",
        .look = &.{
            "boot: stzos init -- machine qemu_hello (hosted / x86_64 / qemu_pc) -- pid 1",
            "boot: mount proc at /proc -- done",
            "hello from a declared machine -- stzr on stzos, a Luau world under PID 1",
            "A kernel was built, an image packed, QEMU booted and a world ran -- and every",
            "line of it came from the one text file you judged in lesson 1.",
        },
        .breakit = "Delete the CONSOLE clause from the machine and rebuild. The boot goes silent: the console a machine narrates on is declared like everything else.",
        .law = "The transcript is the fixture; it is never stored. Rendered from the run into zig-out/, gitignored.",
        .story = "experiment/PROTOCOL.md (OS-2)",
        .needs = &.{ "experiment/os2_image.sh", "experiment/PROTOCOL.md" },
    },
    .{
        .act = "II. THE BOOT",
        .title = "The machine judges its OWN boot, in its own words",
        .question = "Who decides whether a boot went as declared -- and what if the judge is not there to ask?",
        .run = "(the transcript of lesson 4) look for the judge line",
        .look = &.{
            "boot: judge -- the boot matches its expectation (/etc/expected, 16 lines)",
            "The image CARRIES the lines a faithful boot prints, derived from the plan.",
            "PID 1 records what it said and compares the two when every world is ready.",
            "On a card with A/B slots, a trial commits ONLY on a match.",
        },
        .breakit = "Add a fourth service to the machine and rebuild. The boot still runs, and then names the line it expected and did not say -- and on the flagship, that verdict is what holds a trial back.",
        .law = "The machine judges its own boot: a trial commits only on a match, and no expectation is no commit.",
        .story = "experiment/PROTOCOL.md (JDG-1)",
        .needs = &.{"experiment/PROTOCOL.md"},
    },
    .{
        .act = "II. THE BOOT",
        .title = "A pin is not a record of what happened -- it is a claim that it was right",
        .question = "The boot judged itself. Who judges the judge?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_hello",
        .look = &.{
            "JUDGED: the boot transcript matches machines/qemu_hello.expected line for line (35 lines)",
            "The court normalises what no two boots share -- the pids, a dhcp lease, a",
            "device's own key fingerprint -- and diffs the rest against a pinned text.",
        },
        .breakit = "Change one word in machines/qemu_hello.expected and run again: a unified diff, and a FAIL. Then put it back. Never copy a transcript over its pin without reading that diff -- doing it blindly once pinned four broken machines in this repository.",
        .law = "A PIN is not a record of what happened, it is a claim that what happened was RIGHT.",
        .story = "experiment/PROTOCOL.md (SYS-1)",
        .needs = &.{ "machines/qemu_hello.expected", "experiment/os2_image.sh" },
    },

    // ---- III. what a world may do --------------------------------------
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "Six worlds, four questions, and only their declarations differ",
        .question = "A world says what it NEEDS. What happens to what it did not ask for?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_confine",
        .look = &.{
            "confined: eth0 -- no such interface from here: this world has a network namespace of its own",
            "confined: fork -- refused by the kernel (EPERM): this world cannot start another process",
            "confined: processes -- this world is pid 1 and no other process exists here",
            "Same machine, same binary. The only thing separating these worlds is one word",
            "in each one's NEEDS -- and none of it is declared anywhere: it is DERIVED.",
        },
        .breakit = "Give `blind` NEEDS [process, network] and rebuild. eth0 appears for it. Take `network` away from `open` and it vanishes. The envelope follows the declaration and nothing else.",
        .law = "The envelope is DERIVED from NEEDS, never declared: what a world did not ask for, the kernel does not give it.",
        .story = "experiment/PROTOCOL.md (NS-1, MNT-1, PID-1)",
        .needs = &.{ "machines/qemu_confine.machine", "experiment/os2_image.sh" },
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "And some things no world may do, whatever it declared",
        .question = "Is there anything a declaration should never be able to ask for?",
        .run = "(the transcript of lesson 7) look for the floor",
        .look = &.{
            "boot: floor -- the machine is not a world's to change: none may mount or unmount,",
            "  set the clock, load a module, rename the host, make or enter a namespace,",
            "  trace another process, or reboot the box",
            "confined: the floor -- refused by the kernel (EPERM)",
            "Read that last line under `open`, the world that declared EVERYTHING. It is",
            "refused too. No clause grants these, because no declaration should ask.",
        },
        .breakit = "There is nothing to break, and that is the lesson: there is no clause to set. If you want to see it bite, add a world running `/stzos confined eth0` and watch it get the same EPERM.",
        .law = "Some things are refused by what a world IS, not by what it declared.",
        .story = "experiment/PROTOCOL.md (SYS-1)",
        .needs = &.{"experiment/PROTOCOL.md"},
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "Which storage is whose",
        .question = "Two worlds on one box, both trusted with the filesystem. Must they see each other's data?",
        .run = "(the transcript of lesson 7) look for ledger and caisse",
        .look = &.{
            "ledger:  /data -- mounted here      /var/log -- an empty directory, nothing mounted",
            "caisse:  /data -- an empty directory  /var/log -- mounted here",
            "Exact mirrors. Same capability granted to both; the only difference is which",
            "mount each one NAMED in SEES, and neither can read the other's.",
        },
        .breakit = "Give `ledger` SEES [data, logs] and rebuild: it sees both. Take SEES off entirely and it sees both again -- silence does not narrow, because `filesystem` was already the grant.",
        .law = "Derive while the declaration already knows; add a CLAUSE when it does not.",
        .story = "experiment/PROTOCOL.md (SEE-1)",
        .needs = &.{"machines/qemu_confine.machine"},
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "A budget the KERNEL holds, not the world",
        .question = "A world asks for more than it was granted. Who stops it, and how does it feel?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_budget",
        .look = &.{
            "modest: 8 MiB held, well inside the ceiling -- the kernel never had to intervene",
            "swarm: 5 tasks made, and the kernel refused the next (AGAIN)",
            "boot: greedy (pid N) killed by signal 9",
            "Three worlds, three ceilings, and they do not behave alike: memory KILLS,",
            "tasks refuse with EAGAIN, cpu throttles and says nothing. Each is the",
            "kernel's own answer, and the neighbour never felt any of it.",
        },
        .breakit = "Raise greedy's MEMORY to 128 and rebuild: it runs to the end and says nothing. A held ceiling is invisible -- which is why the demonstration needs a world that asks for too much.",
        .law = "A budget is the KERNEL's to hold. A machine that declares no budget mounts no cgroup filesystem and asks for no controller.",
        .story = "experiment/PROTOCOL.md (BDG-1, THR-1)",
        .needs = &.{ "machines/qemu_budget.machine", "experiment/os2_image.sh" },
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "How far a granted network reaches",
        .question = "The box may speak. May it speak to ANYONE?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_egress",
        .look = &.{
            "reach 10.9.0.1 -- a route exists: this machine knows a way there",
            "reach 8.8.8.8 -- no route: this machine knows no way there",
            "Neither witness sent a packet. A UDP connect() is a route lookup and nothing",
            "more, so the box that may not speak to the world never does -- not even to",
            "find out whether it could.",
        },
        .breakit = "Remove the EGRESS clause and rebuild. The declared gateway becomes a default route and 8.8.8.8 is suddenly reachable. The perimeter was one line.",
        .law = "A reach is the declaration's to say. Say precisely what that is and is not: the machine knows no way there; it is not prevented from finding one.",
        .story = "experiment/PROTOCOL.md (EGR-1)",
        .needs = &.{ "machines/qemu_egress.machine", "experiment/os2_image.sh" },
    },

    // ---- IV. who a device is -------------------------------------------
    .{
        .act = "IV. WHO A DEVICE IS",
        .title = "A device's name is its KEY, and the key survives the power",
        .question = "Two boxes run the same image. What makes one of them THIS box?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_identity",
        .look = &.{
            "boot:  identity -- ed25519, custody a file at /data/device.key -- created on this device, fingerprint KEY1",
            "again: identity -- ed25519, custody a file at /data/device.key -- already on this device, fingerprint KEY1",
            "The same disk, booted twice. CREATED, then ALREADY -- and the same KEY1 both",
            "times, because the court maps each DISTINCT fingerprint to KEY1, KEY2, ...",
            "rather than to a constant. A key that had changed would read KEY2 and convict.",
        },
        .breakit = "Move IDENTITY to a path outside any declared MOUNT and run `stzos check`: refused. A key on a filesystem that dies with the power is a new device every morning.",
        .law = "A device's name is its KEY, and it must survive the power.",
        .story = "experiment/PROTOCOL.md (IDN-1)",
        .needs = &.{ "machines/qemu_identity.machine", "experiment/os2_image.sh" },
    },
    .{
        .act = "IV. WHO A DEVICE IS",
        .title = "The machine's own signed record of every boot",
        .question = "What did this box do, and how would you know if someone edited the answer?",
        .run = "(the transcript of lesson 12) look for the journal",
        .look = &.{
            "boot:  journal -- the chain begins, entry 1 signed by this device (verdict matched)",
            "again: journal -- 1 entry verified, entry 2 appended and signed (verdict matched)",
            "One line per boot, hash-chained and signed. It records what the MACHINE was",
            "and what it judged of itself -- never what a world did, which is the world's.",
            "On the flagship you can find an entry that says `verdict differed`: the box",
            "writing down that its own boot was not the declared one.",
        },
        .breakit = "Nothing to edit by hand -- but `zig build test` runs a unit test that changes one word of entry two (the verdict, which is exactly the field someone would want to change) and proves it is caught, with its position and its reason.",
        .law = "A record is the FLOOR's or a world's, never both. Inalterability is that a change cannot go unnoticed, not that a file cannot be changed.",
        .story = "experiment/PROTOCOL.md (JRN-1)",
        .needs = &.{"src/journal.zig"},
    },
    .{
        .act = "IV. WHO A DEVICE IS",
        .title = "A record verified by something that never held the secret",
        .question = "Only the device can check its own signature. Is that evidence, or just a claim?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os7_fleet.sh",
        .look = &.{
            "verify:     1 entry verified against the enrolled key, and no secret took part",
            "tampered:   entry 1 is not this device's: the entry's own bytes do not hash to the hash it carries",
            "foreign:    entry 1 is not this device's: this device's key did not sign this entry",
            "unenrolled: temoin has no KEY in this fleet: nobody can speak for its records",
            "The device made a key and published only the PUBLIC half. Somebody wrote it",
            "into a fleet file by hand. From then on anyone holding that file can check.",
        },
        .breakit = "The negatives ARE the lesson, and the script runs all three. Read them in order: a good record, one word changed, the same record offered as another device's, and a member nobody enrolled.",
        .law = "A claim only its author can check is not evidence.",
        .story = "experiment/PROTOCOL.md (FLT-1)",
        .needs = &.{ "experiment/os7_fleet.sh", "machines/fleet_temoin.machine" },
    },

    // ---- V. the network ------------------------------------------------
    .{
        .act = "V. THE NETWORK",
        .title = "The box is the network's own server of names",
        .question = "The kitchen printer comes back on a different number after every power cut. Why?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os6_names.sh",
        .look = &.{
            "till: ask imprimante.makeen -- 192.168.10.50 (from 192.168.10.1)",
            "till: ask fantome.makeen -- no such name on this network",
            "stranger: network salle -- eth0 dhcp: no lease after 3 tries (no server answered)",
            "TWO machines booted at once on one wire. The till declares no address, no",
            "resolver and no printer, learns all three from the link, and asks by name.",
            "There is NO POOL: the register of who has which address cannot be lost at a",
            "reboot because there is no register -- there is the declaration, in git.",
        },
        .breakit = "Change the till's hardware address in machines/salle_makeen.fleet and run again: it becomes the stranger, and gets nothing. An undeclared device is answered with silence, which is the truth about a network it was never declared on.",
        .law = "A machine that SERVES a link is not finished when its services are. No pool, no range -- the declaration IS the register.",
        .story = "experiment/PROTOCOL.md (NAM-1)",
        .needs = &.{ "experiment/os6_names.sh", "machines/makeen_names.machine", "machines/caisse_makeen.machine" },
    },
    .{
        .act = "V. THE NETWORK",
        .title = "Some facts are about a SET",
        .question = "Two machines are each faultless. Can the pair still be wrong?",
        .run = "stzos fleet machines/salle_makeen.fleet",
        .runnable = true,
        .look = &.{
            "fleet salle_makeen -- 2 members on salle, served by boitier -- judged, no refusal",
            "  caisse -- caisse_makeen (..., asks) -- 52:54:00:12:34:61, promised 192.168.10.40 as caisse",
            "The roll says who is in the set, what each one is, which promise each answers",
            "to, and -- the part that matters -- who nobody can speak for yet.",
        },
        .breakit = "Point a second MEMBER at machines/makeen_names.machine (or any machine that also declares DOMAIN on salle). Both machines pass `stzos check` alone; the FLEET refuses them, because one link has one server of names.",
        .law = "Some facts are about a SET and belong in a file about a set.",
        .story = "declarative/fleet/GRAMMAR.md",
        .needs = &.{ "machines/salle_makeen.fleet", "declarative/fleet/GRAMMAR.md" },
    },

    // ---- VI. the flagship ----------------------------------------------
    .{
        .act = "VI. THE FLAGSHIP",
        .title = "The Makeen box: four boots of one card, and a verdict it refused to commit",
        .question = "A box in a restaurant takes an update at two in the morning and it is wrong. Then what?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh makeen_box",
        .look = &.{
            "boot:   slot B -- committed: every service is ready and has held its health window",
            "steady: identity -- already on this device, fingerprint KEY1",
            "hold:   the same trial on a pristine card, held -- never committed",
            "unmet:  journal -- the chain begins, entry 1 signed by this device (verdict differed)",
            "Four boots of one card in one transcript, 129 lines. The last is the one to",
            "read twice: the box wrote down that its boot was NOT the declared one. That",
            "is the line an auditor wants and the line a vendor's box would never keep.",
        },
        .breakit = "Look at the `hold:` section -- that is the rollback instrument on a pristine card: the trial is never committed, the watchdog is not fed, and the firmware would boot the committed slot. The emulator cannot arm a watchdog, and the transcript says so rather than pretending.",
        .law = "A trial commits only on a match, and no expectation is no commit.",
        .story = "declarative/machine/PINNING.md",
        .needs = &.{ "machines/makeen_box.machine", "experiment/os2_image.sh" },
    },
    .{
        .act = "VI. THE FLAGSHIP",
        .title = "The four standing promises, judged by name",
        .question = "What does this floor actually promise a merchant, and can the promise be checked?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/judge_guarantees.sh",
        .look = &.{
            "the four promises of the hosted profile -- always reachable, a stable name,",
            "a durable log, survives the cut -- each judged KEPT or NOT against the box's",
            "own transcript, twice: once through the board's expectation and once through",
            "the emulator's.",
        },
        .breakit = "The judge reads ONLY lines that begin `boot: ` and are not `boot: judge --`. Before that it searched the whole text and found the words it wanted inside the sentence that DENIED them -- reporting a promise kept by citing the line saying it was missing.",
        .law = "Evidence is what the machine said about THIS boot, never what it quoted about another.",
        .story = "experiment/PROTOCOL.md (GRT-1)",
        .needs = &.{"experiment/judge_guarantees.sh"},
    },
};

fn rule(w: *std.Io.Writer) !void {
    try w.print("  {s}\n", .{"-" ** 68});
}

pub fn list(w: *std.Io.Writer) !void {
    try w.print("\nstzos learn -- {d} lessons. Each one is a command you run, the lines to\n", .{lessons.len});
    try w.print("look for, and a way to BREAK it so the machine convicts you.\n\n", .{});
    var act: []const u8 = "";
    for (lessons, 1..) |l, i| {
        if (!std.mem.eql(u8, act, l.act)) {
            act = l.act;
            try w.print("  {s}\n", .{act});
        }
        try w.print("   {d:>2}  {s}\n", .{ i, l.title });
    }
    try w.print("\n  stzos learn <n>     one lesson in full\n", .{});
    try w.print("  stzos learn --all   all of them, in order\n", .{});
    try w.print("  stzos learn <n> --run   run the command, when it is one of this binary's\n\n", .{});
}

pub fn one(w: *std.Io.Writer, n: usize) !void {
    const l = lessons[n - 1];
    try w.print("\n  Lesson {d} of {d} -- {s}\n", .{ n, lessons.len, l.act });
    try rule(w);
    try w.print("  {s}\n\n", .{l.title});
    try w.print("  THE QUESTION\n    {s}\n\n", .{l.question});
    try w.print("  RUN\n    {s}\n\n", .{l.run});
    try w.print("  LOOK FOR\n", .{});
    for (l.look) |line| try w.print("    {s}\n", .{line});
    try w.print("\n  BREAK IT\n    {s}\n\n", .{l.breakit});
    try w.print("  THE LAW IT PAID FOR\n    {s}\n\n", .{l.law});
    try w.print("  THE FULL STORY\n    {s}\n\n", .{l.story});
}

pub fn all(w: *std.Io.Writer) !void {
    for (lessons, 1..) |_, i| try one(w, i);
}

/// Walk every path a lesson names. A curriculum that points at a machine
/// somebody renamed is a tutorial that lies, and this is what stops it:
/// `zig build court` runs this, so the lie fails in the commit that made
/// it rather than the first time a reader tries to follow along.
pub fn check(w: *std.Io.Writer) !usize {
    var missing: usize = 0;
    for (lessons, 1..) |l, i| {
        for (l.needs) |p| {
            std.fs.cwd().access(p, .{}) catch {
                missing += 1;
                try w.print("  lesson {d} names {s}, which is not there\n", .{ i, p });
            };
        }
    }
    if (missing == 0) {
        try w.print("learn -- {d} lessons, every path they name is present\n", .{lessons.len});
    } else {
        try w.print("learn -- {d} path(s) named by a lesson are missing\n", .{missing});
    }
    return missing;
}

test "every lesson is complete, and the acts run in order" {
    const t = std.testing;
    try t.expect(lessons.len >= 12);
    var seen: [8][]const u8 = undefined;
    var nacts: usize = 0;
    for (lessons) |l| {
        try t.expect(l.title.len > 0 and l.question.len > 0 and l.run.len > 0);
        try t.expect(l.look.len > 0);
        try t.expect(l.breakit.len > 0);
        try t.expect(l.law.len > 0);
        try t.expect(l.story.len > 0);
        // an act appears once and is never returned to: a reader who
        // stops half way should have finished a whole part of the story
        var fresh = true;
        for (seen[0..nacts]) |s| if (std.mem.eql(u8, s, l.act)) {
            fresh = false;
        };
        if (fresh) {
            seen[nacts] = l.act;
            nacts += 1;
        } else {
            try t.expect(std.mem.eql(u8, seen[nacts - 1], l.act));
        }
    }
    try t.expect(nacts >= 5);
}

test "a lesson that can be run names a verb of this binary" {
    const t = std.testing;
    for (lessons) |l| {
        if (!l.runnable) continue;
        try t.expect(std.mem.startsWith(u8, l.run, "stzos "));
    }
}
