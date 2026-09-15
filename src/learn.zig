//! `stzos learn` -- the guided tour of what this machine does and why
//! (LRN-1, redesigned after its first reader).
//!
//! ## What the first reader taught it
//!
//! Lesson 1 said "add a service whose RUN is a shell and check again".
//! The reader did exactly that, and it worked -- but they had to guess
//! WHICH file, WHERE in it, what a service needs to be legal, which
//! directory to stand in, and how to put the file back afterwards. None
//! of that is in the lesson, and all of it is in the author's head.
//!
//! So a BREAK IT step is now five things, and never fewer: the file, the
//! exact text, the command, the line you should see, and the undo. If a
//! step cannot be written that way it is not a step, it is an
//! assumption.
//!
//! ## Why the tour lives in the binary
//!
//! Everything here is judged by something that would notice if it
//! drifted: the grammar by its fixtures, the boot by its own
//! expectation, the transcript by its pin. A tutorial written as prose
//! has no such judge -- it says "run this and you will see that", and
//! nothing checks that the file still exists or that the verb is still
//! spelled that way.
//!
//! So the curriculum is a table beside the verbs it teaches, every
//! lesson declares the paths it names, and `zig build court` runs
//! `stzos learn --check` over them.

const std = @import("std");
/// the floor's own deny list, so a lesson that counts it cannot drift
/// from it: the count below is this array's length, not a word somebody
/// typed (lesson 8)
const confine = @import("confine.zig");

/// How to make the machine refuse YOU. A guarantee you have only watched
/// succeed is a claim; one that has turned you down is evidence.
pub const Break = struct {
    /// what the reader does with `paste` -- the difference between
    /// adding a line and replacing one is not something to leave them
    /// to infer from the prose
    pub const How = enum { append, replace, create };

    /// one sentence: what you are about to prove
    proves: []const u8,
    /// the file to open, exactly as you would type it
    file: []const u8 = "",
    /// where in that file, in plain words
    where: []const u8 = "",
    how: How = .append,
    /// the exact text to put there, line by line
    paste: []const []const u8 = &.{},
    /// the command to run afterwards
    then: []const u8 = "",
    /// the line you should see
    expect: []const []const u8 = &.{},
    /// how to put everything back
    undo: []const u8 = "",
    /// for a lesson where nothing is edited and something is only read
    note: []const u8 = "",
};

pub const Lesson = struct {
    act: []const u8,
    title: []const u8,
    question: []const u8,
    run: []const u8,
    /// true when `run` is a verb of this same binary, so `--run` can
    /// spawn it. The boots are WSL scripts and are never spawned from
    /// here: the machine that runs them is not the one you type on.
    runnable: bool = false,
    look: []const []const u8,
    breakit: Break,
    law: []const u8,
    story: []const u8,
    /// paths this lesson names, walked by `--check` so a lesson cannot
    /// outlive what it points at
    needs: []const []const u8 = &.{},
};

/// How a reader types this binary's name from the repository root. The
/// lessons print it verbatim rather than saying "stzos", because the
/// first reader of this tour ran one command from `zig-out\bin` and the
/// next from the root, and had to work out on their own why a relative
/// machine path stopped resolving.
pub const exe = "zig-out\\bin\\stzos.exe";
const EXE = exe;

pub const words = [_][2][]const u8{
    .{ "a machine", "One computer, written down: what it is, what it mounts, what it runs. A `.machine` file under `machines\\`. Nothing more -- it is text until something builds it." },
    .{ "a declaration", "A block in that file: `DEFINE SERVICE mine AS ( ... ) RATIONALE \"...\"`. The RATIONALE is not a comment; the grammar requires it, so every part of a machine says why it is there." },
    .{ "a clause", "One line inside a declaration, like `RUN [...]` or `NEEDS [...]`. Each kind of declaration has a closed list of clauses it accepts, and anything else is refused by name." },
    .{ "a world", "One running program the machine declared -- a SERVICE, once it is alive. Called a world because it gets its own little universe: its own view of the network, the storage and the process table." },
    .{ "the envelope", "What the kernel lets a world see and do. Derived from what the world declared it NEEDS, never granted by a separate permission file." },
    .{ "the court", "The judge of the grammar. A file of cases -- some that must be ACCEPTED, more that must be REFUSED, each with the exact words its refusal has to contain. `zig build court` runs them all." },
    .{ "a pin", "A stored copy of everything a boot should print. Boot again and the court diffs the two, so any change shows up as a diff instead of a shrug." },
    .{ "the transcript", "Everything one boot actually printed, from the first line of PID 1 to the halt." },
    .{ "PID 1", "The first process the kernel starts, which on this machine is `stzos` itself. It mounts, it starts the worlds, it reaps them, and it narrates every step." },
    .{ "a fleet", "A set of machines judged TOGETHER, in a `.fleet` file. Some mistakes are only visible across a set -- two boxes that each call themselves the server of one network are each faultless alone." },
    .{ "a seat", "One unit of work in this project's history, tagged like `NS-1` or `SEE-1`. Every doctrine line names the seat that paid for it, and `experiment/PROTOCOL.md` tells each story in full." },
};

pub const lessons = [_]Lesson{
    // ---- I. the declaration -------------------------------------------
    .{
        .act = "I. THE DECLARATION",
        .title = "A machine is a text file, and it is judged before anything runs",
        .question = "What IS a machine here, before any of it exists?",
        .run = EXE ++ " check machines\\qemu_hello.machine",
        .runnable = true,
        .look = &.{
            "machine qemu_hello -- hosted / x86_64 / kernel linux -- 3 service(s), ... judged, no refusal",
            "",
            "Nothing was built, mounted or started. A file was read and a verdict given,",
            "and that verdict is the whole of what this command does. Everything later in",
            "the tour comes from this one file.",
        },
        .breakit = .{
            .proves = "that the grammar really will not let a machine ask for a shell",
            .file = "machines\\qemu_hello.machine",
            .where = "at the very END of the file, after the last `) RATIONALE \"...\"` line",
            .paste = &.{
                "DEFINE SERVICE mine AS (",
                "  RUN [\"sh\", \"-c\", \"echo hi\"]",
                ") RATIONALE \"I am learning how a machine is declared\"",
            },
            .then = EXE ++ " check machines\\qemu_hello.machine",
            .expect = &.{
                "machine (line 55): A service is an argv, never a shell line: the boot path",
                "has no shell ('sh')",
                "",
                "Note what it did NOT complain about. Your service left out RESTART and",
                "NEEDS, and both are optional -- swap \"sh\" for \"/stzos\" and the same three",
                "lines are accepted as a fourth service. The ONLY thing wrong was the shell.",
            },
            .undo = "git checkout -- machines/qemu_hello.machine",
        },
        .law = "Closed grammars have no host escape.",
        .story = "declarative/machine/GRAMMAR.md",
        .needs = &.{ "machines/qemu_hello.machine", "declarative/machine/GRAMMAR.md" },
    },
    .{
        .act = "I. THE DECLARATION",
        .title = "The declaration becomes a plan, and nothing else",
        .question = "What does the machine intend to do, in order, before it does any of it?",
        .run = EXE ++ " plan machines\\qemu_confine.machine",
        .runnable = true,
        .look = &.{
            "Every step in the order it will happen: the mounts the profile adds by itself,",
            "then the declared ones, then each capability granted or refused, then the",
            "worlds. Read the last two lines -- each says what that world needs and which",
            "storage it keeps:",
            "",
            "  start ledger ... needs [process, network, filesystem] -- sees [data]",
            "  start caisse ... needs [process, network, filesystem] -- sees [logs]",
        },
        .breakit = .{
            .proves = "that the order is the declaration's, and a circle in it is caught",
            .file = "machines\\qemu_confine.machine",
            .where = "in the `sealed` service near the end of the file, on the line just below `DEFINE SERVICE sealed AS (` -- it has no AFTER clause today",
            .paste = &.{
                "  AFTER [caisse],",
            },
            .then = EXE ++ " plan machines\\qemu_confine.machine",
            .expect = &.{
                "A refusal naming the cycle. `sealed` would come after `caisse`, which comes",
                "after `ledger`, which comes after `blind` ... which comes after `sealed`.",
                "No order exists, so none is invented.",
            },
            .undo = "git checkout -- machines/qemu_confine.machine",
        },
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
            "learn -- 18 lessons, every path they name is present",
            "",
            "Eighty-four of those cases are things the language REFUSES, and each one",
            "carries the exact words its refusal must contain. So refusing for the wrong",
            "reason fails as loudly as not refusing at all.",
        },
        .breakit = .{
            .proves = "that the court checks the REASON, not just that something was refused",
            .file = "declarative\\machine\\fixtures.json",
            .where = "search for \"id\": \"R1\" and find the \"refusal\" line just below it",
            .how = .replace,
            .paste = &.{
                "\"refusal\": \"something the parser would never say\",",
            },
            .then = "zig build court -j2",
            .expect = &.{
                "FAIL R1 ... -- refused for the wrong reason: line 1: <what it really said>",
                "(expected 'something the parser would never say')",
                "",
                "The case is still refused. The court fails anyway, because a refusal for",
                "the wrong reason is a different machine wearing the right answer.",
            },
            .undo = "git checkout -- declarative/machine/fixtures.json",
        },
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
            "",
            "A Linux kernel was configured and built, an image packed, QEMU booted, three",
            "worlds run and the box halted. Every line of it came from the one text file",
            "you judged in lesson 1. This takes a few minutes the first time and about",
            "thirty seconds afterwards, because the kernel build is cached.",
        },
        .breakit = .{
            .proves = "that even the console a machine talks on is declared",
            .file = "machines\\qemu_hello.machine",
            .where = "in the DEFINE MACHINE block at the top, on the CONSOLE line",
            .how = .replace,
            .paste = &.{
                "  CONSOLE \"/dev/ttyS3\"",
            },
            .then = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_hello",
            .expect = &.{
                "The boot goes SILENT. QEMU shows the kernel's own lines and then nothing,",
                "because PID 1 is narrating to a serial port that is not the one the",
                "emulator is showing you. The machine is running fine and talking to a wall.",
            },
            .undo = "git checkout -- machines/qemu_hello.machine",
        },
        .law = "The transcript is the fixture; it is never stored. Rendered from the run into zig-out/, gitignored.",
        .story = "experiment/PROTOCOL.md (OS-2)",
        .needs = &.{ "experiment/os2_image.sh", "experiment/PROTOCOL.md" },
    },
    .{
        .act = "II. THE BOOT",
        .title = "The machine judges its OWN boot, in its own words",
        .question = "Who decides whether a boot went as declared?",
        .run = "(read the output of lesson 4 and find the line beginning `boot: judge`)",
        .look = &.{
            "boot: judge -- the boot matches its expectation (/etc/expected, 16 lines)",
            "",
            "The image CARRIES the lines a faithful boot prints, worked out from the plan",
            "before the image was even packed. PID 1 writes down what it said and compares",
            "the two once every world is ready. On a box with two system slots, an update",
            "is kept only if that comparison matches.",
        },
        .breakit = .{
            .proves = "that the expectation moves WITH the declaration, so a match is not a rubber stamp",
            .file = "machines\\qemu_hello.machine",
            .where = "at the very END of the file",
            .paste = &.{
                "DEFINE SERVICE extra AS (",
                "  RUN [\"/stzos\", \"version\"],",
                "  NEEDS [process]",
                ") RATIONALE \"A world the expectation was written before\"",
            },
            .then = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_hello",
            .expect = &.{
                "It still boots. Then it judges itself and says so:",
                "",
                "  boot: judge -- the boot matches its expectation (/etc/expected, 18 lines)",
                "",
                "Eighteen, where it counted 16 before: your service added lines to BOTH the",
                "transcript and the expectation.",
                "",
                "It MATCHES, because the expectation was derived from the same file you just",
                "edited -- change the machine and its expectation changes with it. To see a",
                "MISMATCH you have to change what the machine SAYS without changing what it",
                "DECLARES. Two places in this tour do exactly that, and neither needs you",
                "to edit anything: the `stranger` in lesson 15, which is this same kind of",
                "image booted onto a wire that will not lease it an address, and the",
                "flagship's `unmet:` section in lesson 17, where the emulator lacks",
                "hardware the board has. Lesson 15's is the cleaner one -- nothing about",
                "the declaration differs at all, only the wire.",
            },
            .undo = "git checkout -- machines/qemu_hello.machine",
        },
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
            "",
            "The court takes what the boot printed, replaces the few things no two boots",
            "share -- the process numbers, a leased address, a device's key fingerprint --",
            "and diffs the rest against a stored text.",
        },
        .breakit = .{
            .proves = "that the pin is compared line for line, not skimmed",
            .file = "machines\\qemu_hello.expected",
            .where = "line 2, which today reads  boot: console /dev/ttyS0",
            .how = .replace,
            .paste = &.{
                "boot: console /dev/ttyS9",
            },
            .then = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_hello",
            .expect = &.{
                "JUDGED: FAIL -- the transcript differs from machines/qemu_hello.expected:",
                "followed by a unified diff showing exactly your one-character edit.",
                "",
                "Now the important part. When a diff appears, READ IT before you replace the",
                "pin. Copying a transcript over its expectation without reading the diff",
                "once pinned four broken machines in this repository in a single afternoon.",
            },
            .undo = "git checkout -- machines/qemu_hello.expected",
        },
        .law = "A PIN is not a record of what happened, it is a claim that what happened was RIGHT.",
        .story = "experiment/PROTOCOL.md (SYS-1)",
        .needs = &.{ "machines/qemu_hello.expected", "experiment/os2_image.sh" },
    },

    // ---- III. what a world may do --------------------------------------
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "Six worlds, the same six questions, and only their declarations differ",
        .question = "A world says what it NEEDS. What happens to what it did not ask for?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_confine",
        .look = &.{
            "Six worlds run the SAME command -- /stzos confined eth0 /data /var/log --",
            "and each reports what it can actually reach. Line them up:",
            "",
            "  world    what it declared              eth0      /data     fork",
            "  ------   ---------------------------   -------   -------   ---------",
            "  sealed   process, filesystem           absent    mounted   permitted",
            "  still    network, filesystem           present   mounted   REFUSED",
            "  open     process, network, filesystem  present   mounted   permitted",
            "  blind    process                       absent    empty     permitted",
            "  ledger   all three, SEES [data]        present   mounted   permitted",
            "  caisse   all three, SEES [logs]        present   empty     permitted",
            "",
            "Read any row against its declaration. `still` never asked for `process`, so",
            "the kernel refuses it a second one AND gives it a process table of its own",
            "where it is pid 1. `blind` asked for nothing but the right to run, so it has",
            "no interface and its /data is an empty directory -- which the witness says",
            "in those words, because a directory that is THERE with nothing mounted on it",
            "is a different fact from a directory that is missing.",
            "",
            "None of this grid is declared anywhere. It is worked out FROM what each",
            "world asked for, and one binary produced every row.",
        },
        .breakit = .{
            .proves = "that the envelope follows the declaration and nothing else",
            .file = "machines\\qemu_confine.machine",
            .where = "in the `blind` service near the end, on its `NEEDS [process]` line",
            .how = .replace,
            .paste = &.{
                "  NEEDS [process, network]",
            },
            .then = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_confine",
            .expect = &.{
                "confined: eth0 -- present: this world shares the machine's network",
                "",
                "where `blind` said `no such interface from here` before. One word.",
                "",
                "Now read the pin's diff in step 6, because EXACTLY TWO lines of a 65-line",
                "transcript changed and the second one is the interesting half:",
                "",
                "  -boot: confine -- ... blind has no network of its own and no sight of",
                "                        /data, /var/log ...",
                "  +boot: confine -- ... blind has no sight of /data, /var/log ...",
                "",
                "That is PID 1, before it started anything, announcing what it was about",
                "to withhold -- and it dropped the network clause at the same moment the",
                "world inside gained the interface. The announcement and the fact moved",
                "together.",
                "",
                "A machine that announced a confinement it did not apply, or applied one",
                "it never announced, would show ONE of those two lines moving without the",
                "other. That is the defect NS-1 is named for, and this diff is how you",
                "would catch it. Everything else about `blind` is untouched: /data still",
                "empty, the floor still refused.",
            },
            .undo = "git checkout -- machines/qemu_confine.machine",
        },
        .law = "The envelope is DERIVED from NEEDS, never declared: what a world did not ask for, the kernel does not give it.",
        .story = "experiment/PROTOCOL.md (NS-1, MNT-1, PID-1)",
        .needs = &.{ "machines/qemu_confine.machine", "experiment/os2_image.sh" },
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "And some things no world may do, whatever it declared",
        .question = "Is there anything a declaration should never be able to ask for?",
        .run = "(read the output of lesson 7 and find the lines beginning `boot: floor` and `confined: the floor`)",
        .look = &.{
            "PID 1 says it ONCE, before it starts anything at all:",
            "",
            "  boot: floor -- the machine is not a world's to change: none may mount or",
            "  unmount, set the clock, load a module, rename the host, make or enter a",
            "  namespace, trace another process, or reboot the box",
            "",
            "and then every one of the six worlds reports the same thing from inside:",
            "",
            "  sealed   confined: the floor -- refused by the kernel (EPERM)",
            "  still    confined: the floor -- refused by the kernel (EPERM)",
            "  open     confined: the floor -- refused by the kernel (EPERM)",
            "  blind    confined: the floor -- refused by the kernel (EPERM)",
            "  ledger   confined: the floor -- refused by the kernel (EPERM)",
            "  caisse   confined: the floor -- refused by the kernel (EPERM)",
            "",
            "Six for six, byte for byte. Now look back at lesson 7's grid and find the",
            "row for `open`: process, network AND filesystem -- every capability the",
            "grammar has. It is refused exactly like `blind`, which declared almost",
            "nothing.",
            "",
            std.fmt.comptimePrint("That is because these {d} calls are not governed by NEEDS at all. They are", .{confine.off_limits.len}),
            "refused by what a world IS. There is no clause that grants them, because a",
            "clause that COULD grant them is a clause somebody will eventually use.",
        },
        .breakit = .{
            .proves = "that this one is not a declaration's to ask for at all",
            .note = std.fmt.comptimePrint("There is nothing to edit, and that IS the lesson: no clause to set, no flag to pass, no line you could add to a declaration that would get any of it back. The list is {d} names long and lives in src/confine.zig as `off_limits`, each one grouped under the sentence that explains it -- the filesystem tree is the declaration's, the kernel is the image's, the machine's life is PID 1's. Read it: it is the shortest statement in this repository of what a world is not.", .{confine.off_limits.len}),
        },
        .law = "Some things are refused by what a world IS, not by what it declared.",
        .story = "experiment/PROTOCOL.md (SYS-1)",
        .needs = &.{ "src/confine.zig", "experiment/PROTOCOL.md" },
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "Which storage is whose",
        .question = "Two worlds on one box, both trusted with the filesystem. Must they see each other's data?",
        .run = "(read the output of lesson 7 and find the `ledger` and `caisse` sections)",
        .look = &.{
            "Two worlds whose NEEDS are identical, word for word:",
            "",
            "  ledger   NEEDS [process, network, filesystem],  SEES [data]",
            "  caisse   NEEDS [process, network, filesystem],  SEES [logs]",
            "",
            "and what each can actually reach:",
            "",
            "  ledger   /data     mounted here",
            "  ledger   /var/log  an empty directory and nothing mounted on it",
            "  caisse   /data     an empty directory and nothing mounted on it",
            "  caisse   /var/log  mounted here",
            "",
            "Exact mirrors. The same capability was granted to both, and the only thing",
            "that differs is which mount each one NAMED. Neither can read the other's.",
            "",
            "Read the witness's wording closely, because it was chosen after getting it",
            "wrong once. It does not say /var/log is MISSING from ledger. It says the",
            "directory is there and nothing is mounted on it -- which is the truth, and a",
            "different fact. A witness that had asked `does this path exist?` would have",
            "answered about the empty directory left behind and called a kept promise",
            "broken (MNT-1).",
        },
        .breakit = .{
            .proves = "that saying nothing keeps everything, because the capability was already the grant",
            .file = "machines\\qemu_confine.machine",
            .where = "in the `ledger` service, on its `SEES [data]` line",
            .how = .replace,
            .paste = &.{
                "  SEES [data, logs]",
            },
            .then = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_confine",
            .expect = &.{
                "confined: /var/log -- mounted here: this world can see the machine's storage",
                "",
                "under `ledger`, where it read `an empty directory` before. And in step 6's",
                "diff, exactly two lines again -- PID 1's announcement losing the clause",
                "`ledger has no sight of /var/log`, and the witness inside gaining the",
                "mount. The announcement and the fact move together or the machine is",
                "lying (NS-1).",
                "",
                "NOW THE SECOND HALF, which is the one that names the law. Put the file",
                "back, then delete the SEES clause from `ledger` ALTOGETHER -- these two",
                "lines:",
                "",
                "    NEEDS [process, network, filesystem],",
                "    SEES [data]",
                "",
                "become this one, with the comma gone:",
                "",
                "    NEEDS [process, network, filesystem]",
                "",
                "Boot again. `ledger` sees BOTH mounts, and the diff against the pin is",
                "byte for byte the same diff you just got from saying SEES [data, logs].",
                "The machine cannot tell the two declarations apart, because SEES only",
                "ever NARROWS a grant that NEEDS [filesystem] already made. Silence keeps",
                "everything; it never widens anything.",
                "",
                "That is why SEES had to be a clause rather than a derivation. Which",
                "mounts a world keeps was in nothing the declaration already said, so it",
                "was ASKED FOR. Guessing it from a proxy would have been a guess wearing",
                "a derivation's clothes (SEE-1).",
            },
            .undo = "git checkout -- machines/qemu_confine.machine",
        },
        .law = "Derive while the declaration already knows; add a CLAUSE when it does not.",
        .story = "experiment/PROTOCOL.md (SEE-1)",
        .needs = &.{ "machines/qemu_confine.machine", "machines/qemu_confine.expected" },
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "A budget the KERNEL holds, not the world",
        .question = "A world asks for more than it was granted. Who stops it, and how does it feel?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_budget",
        .look = &.{
            "PID 1 announces every ceiling before any world starts:",
            "",
            "  boot: budget -- modest 64 MiB and 50% of a core, swarm 6 tasks, greedy 32",
            "  MiB; the kernel holds the ceiling, not the world",
            "",
            "and then the three worlds meet their ceilings in three DIFFERENT ways:",
            "",
            "  modest: 8 MiB held, well inside the ceiling -- the kernel never had to",
            "          intervene",
            "  swarm:  5 tasks made, and the kernel refused the next (AGAIN): this world",
            "          is as many as the machine agreed to hold",
            "  boot:   greedy (pid N) killed by signal 9",
            "",
            "TASKS refuses. The world gets EAGAIN back from its own fork, stays alive, and",
            "can say what happened -- which is why `swarm` reports a sentence rather than",
            "dying. MEMORY kills, with a signal nothing can catch. Count the swarm line",
            "if it puzzles you: the declaration says TASKS 6 and the world made FIVE",
            "children, because the ceiling is on the WORLD and the world is the sixth task.",
            "",
            "Then read what PID 1 does about the death, which is the half nobody expects:",
            "",
            "  boot: restart greedy (on_failure, 1/5) -- pid N    ... then 2/5 through 5/5",
            "  boot: greedy -- restart on_failure, but gave up after 5 restarts",
            "",
            "It honours the declared RESTART policy, five times, and then says in one line",
            "that it has stopped trying. The machine does not hang and the other worlds",
            "never felt any of it.",
            "",
            "One honesty about this machine: it demonstrates MEMORY and TASKS and it does",
            "NOT demonstrate CPU. Nothing here exhausts its processor share, so nothing",
            "throttles, so the transcript says nothing -- and a throttle would say nothing",
            "anyway. That is the third behaviour: not a kill, not a refusal, just less of",
            "the machine, silently.",
        },
        .breakit = .{
            .proves = "that the kernel stops a world exactly where the declaration said, and nowhere else",
            .file = "machines\\qemu_budget.machine",
            .where = "in the `swarm` service, on its `TASKS 6,` line",
            .how = .replace,
            .paste = &.{
                "  TASKS 20,",
            },
            .then = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_budget",
            .expect = &.{
                "swarm: 12 tasks made, and the kernel refused none: this world was not sized",
                "",
                "`swarm` asks for twelve every time -- look at its RUN line. At TASKS 6 the",
                "kernel stopped it at five; at TASKS 20 it never reached the ceiling at all,",
                "and the witness SAYS the ceiling was never met rather than leaving you to",
                "infer it from silence. Two lines move in step 6's diff, as ever: PID 1's",
                "announcement (6 tasks -> 20 tasks) and the fact.",
                "",
                "NOW A SECOND EXPERIMENT, and it is the more useful one because it fails.",
                "Put the file back, then raise the OTHER ceiling -- in `greedy`, replace",
                "",
                "    MEMORY 32,",
                "",
                "with",
                "",
                "    MEMORY 128,",
                "",
                "and boot. You might expect `greedy` to survive. It does not: still killed",
                "by signal 9, still restarted five times, still given up on. Exactly ONE",
                "line of the transcript changes, and it is PID 1's announcement --",
                "`greedy 32 MiB` becomes `greedy 128 MiB` -- while everything that",
                "HAPPENS stays identical.",
                "",
                "Read app/greedy.luau and you will see why: it allocates a mebibyte at a",
                "time up to 512, on a machine QEMU gives 256 MiB in total. A ceiling of 128",
                "is still a ceiling it runs straight through. Raising a budget only helps a",
                "world that was going to stop.",
            },
            .undo = "git checkout -- machines/qemu_budget.machine",
        },
        .law = "A budget is the KERNEL's to hold. A machine that declares no budget mounts no cgroup filesystem and asks for no controller.",
        .story = "experiment/PROTOCOL.md (BDG-1, THR-1)",
        .needs = &.{ "machines/qemu_budget.machine", "app/greedy.luau", "experiment/os2_image.sh" },
    },
    .{
        .act = "III. WHAT A WORLD MAY DO",
        .title = "How far a granted network reaches",
        .question = "The box may speak. May it speak to ANYONE?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_egress",
        .look = &.{
            "PID 1 states the perimeter before either witness runs:",
            "",
            "  boot: egress lan -- 10.9.0.0/16 and nowhere else: no default route",
            "",
            "and then the two witnesses ask the kernel the same question about two",
            "different addresses:",
            "",
            "  reach 10.9.0.1 -- a route exists: this machine knows a way there",
            "  reach 8.8.8.8  -- no route: this machine knows no way there",
            "",
            "Neither witness sent a packet. Asking the kernel to connect a UDP socket is a",
            "route lookup and nothing more, so the box that may not speak to the open",
            "internet never does -- not even to find out whether it could.",
            "",
            "Read the promise exactly as it is worded, because the wording is the point.",
            "It says the machine knows NO WAY THERE. It does not say the machine is",
            "PREVENTED from finding one. EGRESS writes the routing table; it is not a",
            "packet filter, and a world with the privilege to add a route could add one.",
            "There is no shell on the boot path to do it with and a world running as a",
            "declared USER has no such privilege -- but the claim stops where the",
            "mechanism stops, and says so (EGR-1).",
        },
        .breakit = .{
            .proves = "that the perimeter is one line of declaration",
            .file = "machines\\qemu_egress.machine",
            .where = "in the `lan` network block, on the line reading  EGRESS [\"10.9.0.0/16\"]",
            .how = .replace,
            .paste = &.{
                "  EGRESS [\"0.0.0.0/0\"]",
            },
            .then = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_egress",
            .expect = &.{
                "boot: egress lan -- 0.0.0.0/0: a DEFAULT route, so this machine knows a",
                "way anywhere",
                "reach 8.8.8.8 -- a route exists: this machine knows a way there",
                "",
                "You declared a reach to everything, so a route to everything was written.",
                "Two lines again: the announcement and the fact, moving together.",
                "",
                "That first line is worded the way it is because of THIS lesson. It used to",
                "read `0.0.0.0/0 and nowhere else: no default route` -- a sentence that is",
                "false twice, since 0.0.0.0/0 has no `else` and a route to it through the",
                "gateway is precisely what a default route IS. The boot announced a",
                "perimeter it was not keeping, which is the one thing a boot may never do.",
                "Running this step is what found it.",
                "",
                "NOW THE SECOND EXPERIMENT, which looks equivalent and is not. Put the file",
                "back, then delete the EGRESS clause ALTOGETHER -- these two lines:",
                "",
                "    GATEWAY \"10.0.2.2\",",
                "    EGRESS [\"10.9.0.0/16\"]",
                "",
                "become this one, with the comma gone:",
                "",
                "    GATEWAY \"10.0.2.2\"",
                "",
                "Boot again. 8.8.8.8 is reachable, the same as before -- but the TRANSCRIPT",
                "is different. The `boot: egress` line does not appear at all, because there",
                "is no perimeter to announce, and the network line grows a gateway instead:",
                "",
                "  boot: network lan -- eth0 up 10.0.2.15/24, gateway 10.0.2.2",
                "",
                "Compare that with lesson 9, where saying SEES [data, logs] and saying",
                "nothing produced a byte-identical transcript. Here they do not. Same",
                "outcome, different RECORD: an explicit EGRESS leaves evidence that someone",
                "decided, and silence leaves evidence that nobody did.",
            },
            .undo = "git checkout -- machines/qemu_egress.machine",
        },
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
            "One disk, booted TWICE in one transcript. The second boot's lines are",
            "prefixed `again:` so you can tell them apart:",
            "",
            "  boot:  identity -- ed25519, custody a file at /data/device.key --",
            "           created on this device, fingerprint KEY1",
            "  again: boot: identity -- ed25519, custody a file at /data/device.key --",
            "           already on this device, fingerprint KEY1",
            "",
            "CREATED, then ALREADY, and the same KEY1 both times. The line SAYS the",
            "algorithm and where the key is kept rather than leaving you to assume either.",
            "",
            "KEY1 is not a blank. The court replaces each DISTINCT fingerprint with KEY1,",
            "KEY2, KEY3 as it meets them, so a key that had CHANGED between boots would",
            "read KEY2 on the second line and the pin would convict. Blanking them all to",
            "a constant would have hidden exactly the claim this machine exists to make.",
            "",
            "Now the two lines most worth your attention, which are about a DIFFERENT",
            "thing -- what the key is FOR:",
            "",
            "  attest: signed 21 bytes with this device's key and verified them against",
            "          its public half",
            "  attest: one bit flipped in the message, and the same signature is refused",
            "",
            "The machine breaks its own signature, on every boot, and prints the refusal.",
            "A signature that has only ever been seen to VERIFY is a claim; one that has",
            "been watched to refuse a tampered message is evidence. That is the same",
            "argument this tour makes at you with every BREAK IT step, and here the",
            "machine is making it about itself, unprompted, in its own transcript.",
        },
        .breakit = .{
            .proves = "that a key must live somewhere the power cannot take it",
            .file = "machines\\qemu_identity.machine",
            .where = "in the DEFINE MACHINE block at the top, on the IDENTITY line",
            .how = .replace,
            .paste = &.{
                "  IDENTITY \"/tmp/device.key\",",
            },
            .then = EXE ++ " check machines\\qemu_identity.machine",
            .expect = &.{
                "machine (line 17): IDENTITY /tmp/device.key is where the key lives, and no",
                "declared MOUNT keeps it: a key on a filesystem that dies with the power is",
                "a new device every morning",
                "",
                "No boot, no image, no kernel -- refused in under a second, reading a text",
                "file. Nobody had to remember to put the key somewhere sensible; the",
                "grammar would not let them forget.",
                "",
                "It says line 17 and you edited line 22. That is not a mistake: IDENTITY is",
                "a clause OF the machine, so the refusal is attributed to the DEFINE",
                "MACHINE declaration that owns it, which begins on line 17. The check can",
                "only run once every MOUNT has been read, which is after the whole file.",
                "",
                "NOW THE SHARPER QUESTION, because `/tmp` is an easy case -- nothing is",
                "declared there at all. What if you DECLARE the mount? Put the file back,",
                "then set the key to `/scratch/device.key` and add a mount for it at the",
                "end of the file:",
                "",
                "    DEFINE MOUNT scratch AS (",
                "      AT \"/scratch\",",
                "      FS tmpfs",
                "    ) RATIONALE \"A declared mount that does not survive the power\"",
                "",
                "Check it. Refused, word for word the same. The test is not whether a mount",
                "was DECLARED -- it is whether the mount KEEPS anything. Only ext4 and vfat",
                "satisfy it, because those are the two that are still there after the power",
                "cut. Read the refusal again with that in mind: `no declared MOUNT keeps",
                "it`. The verb was chosen.",
            },
            .undo = "git checkout -- machines/qemu_identity.machine",
        },
        .law = "A device's name is its KEY, and it must survive the power.",
        .story = "experiment/PROTOCOL.md (IDN-1)",
        .needs = &.{ "machines/qemu_identity.machine", "experiment/os2_image.sh" },
    },
    .{
        .act = "IV. WHO A DEVICE IS",
        .title = "The machine's own signed record of every boot",
        .question = "What did this box do, and how would you know if someone edited the answer?",
        .run = "(read the output of lesson 12 and find the lines beginning `journal`)",
        .look = &.{
            "Four lines, in the order they happen. The first boot finds nothing:",
            "",
            "  journal /data/boot.journal -- no record yet: this is the first boot, and",
            "  its entry is written after the verdict",
            "  boot: journal -- /data/boot.journal: the chain begins, entry 1 signed by",
            "  this device (verdict matched)",
            "",
            "and the second boot reads what the first one left, and shows you the entry:",
            "",
            "  again: journal /data/boot.journal -- 1 entry, every one chained to the one",
            "  before it and signed by this device",
            "  again: journal:   seq=1 prev=- machine=qemu_identity",
            "  declaration=a48c59fbf8070f67 verdict=matched",
            "  again: boot: journal -- /data/boot.journal: 1 entry verified, entry 2",
            "  appended and signed (verdict matched)",
            "",
            "Read that `seq=1` line, because it is the whole record and it is meant to be",
            "readable. `prev=-` says nothing came before it. `declaration=` is a digest of",
            "the machine text that ran, so the entry says WHICH declaration this was.",
            "`verdict=matched` is what PID 1 concluded about its own boot. The file holds",
            "one such line per boot, plus a hash and a signature.",
            "",
            "Note the ORDER, which is a rule and not an accident: 1 entry VERIFIED, then",
            "entry 2 appended. A chain is verified before it is extended, because an entry",
            "appended after a broken one would launder the break.",
            "",
            "There is no timestamp, deliberately. The board has no clock and nothing on the",
            "boot path sets one, so a date here would be the epoch wearing authority. The",
            "SEQUENCE is the order. It records what the MACHINE was and what it judged of",
            "itself -- never what a world did, because what a business record IS belongs to",
            "the business. On the flagship you can find an entry reading `verdict",
            "differed`: the box writing down that its own boot was not the declared one.",
        },
        .breakit = .{
            .proves = "that a change to the record cannot go unnoticed",
            .then = "zig build test -j2",
            .expect = &.{
                "31/31 passed. One of them is `a chain verifies, and an altered entry is",
                "named by its position`, in src/journal.zig. Open it and read it -- it is",
                "the evidence for this lesson and it is about forty lines.",
                "",
                "It builds three real entries with a real key, verifies the chain, then",
                "changes ONE WORD in entry two: verdict=matched becomes verdict=perfect,",
                "which is exactly the field someone would want to change. Then it requires",
                "three things, and the third is the one that matters:",
                "",
                "  broken_at == 2        the POSITION, not merely that something is wrong",
                "  verified == 1         entry one still verifies: the break is where the",
                "                        lie is, and not before it",
                "  reason contains       'do not hash to the hash it carries'",
                "",
                "Until this lesson was written that test asserted only `broken_at != null`,",
                "and its tampering used a whole-text replace -- which also hit entry ONE,",
                "since both say verdict=matched -- so the chain actually broke at 1 while",
                "the test's own name claimed it was about 2. It passed either way. A test",
                "that does not check the position cannot be the test that the position is",
                "right, and this lesson quoted it as though it were.",
                "",
                "It then offers the same record to a DIFFERENT device's key and requires",
                "broken_at == 1 and verified == 0: no entry of this chain is that device's,",
                "so the refusal starts at the very first line.",
                "",
                "The claim is carefully worded, and the wording is the law. NOT that a",
                "record cannot be changed -- any file can be changed, including this one --",
                "but that a change cannot go UNNOTICED.",
            },
            .note = "Nothing to edit by hand: the record lives inside an ext4 image the boot creates, so this guarantee is proven beside the code instead. Lesson 14 does the same tampering on a REAL record, from outside the device, using nothing but the public half of its key -- which is the version that counts.",
        },
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
            "The script prints one arc in seven labelled sections. Read them in order.",
            "",
            "The device boots twice, makes its key once, and publishes the PUBLIC half:",
            "",
            "  device: enrol fleet_temoin ed25519 KEY1 -- KEY for this machine's MEMBER",
            "  in a fleet",
            "  device: enrol fleet_temoin ed25519 KEY1 -- KEY for this machine's MEMBER",
            "  in a fleet",
            "  carried: 1 entry off the machine, as the exact bytes that were signed",
            "",
            "-- the same line twice, because the device booted twice and made its key",
            "once.",
            "",
            "`as the exact bytes` is the rule, not a flourish. The signature is over the",
            "bytes on the line, never over an object they were parsed into, so two",
            "spellings of one record cannot verify differently.",
            "",
            "Then the roll, BEFORE anyone enrols that key -- and this is the line to",
            "read twice:",
            "",
            "  roll:   temoin -- fleet_temoin (fleet_temoin.machine) -- KEEPS A RECORD",
            "  AND IS NOT ENROLLED: nobody can verify what it signs",
            "",
            "The fleet does not guess. It does not accept whatever key answered. It",
            "REPORTS that it cannot speak for this device, in capitals, and says what to",
            "do about it. A fleet that enrolled automatically would attribute records to",
            "whatever device happened to be plugged in.",
            "",
            "After a human writes the key in, the same roll reads `enrolled, fingerprint",
            "FP1`, and then the act itself:",
            "",
            "  verify: fleet atelier -- temoin: 1 entry verified against the enrolled",
            "  key (fingerprint FP1), and no secret took part",
            "",
            "Three negatives follow, and they refuse for THREE DIFFERENT REASONS, which",
            "is the part that makes them evidence rather than decoration:",
            "",
            "  tampered: fleet atelier -- temoin: entry 1 is not this device's: the",
            "  entry's own bytes do not hash to the hash it carries: it was altered",
            "  after it was written",
            "  foreign: fleet atelier -- temoin: entry 1 is not this device's: this",
            "  device's key did not sign this entry",
            "  unenrolled: fleet atelier -- temoin has no KEY in this fleet: nobody can",
            "  speak for its records until its own fingerprint is enrolled",
            "",
            "Altered, misattributed, unattributable. The machine says WHICH.",
            "",
            "Last, the estate's own fleet is judged, and it reports on itself as plainly:",
            "",
            "  salle: boitier -- makeen_names ... -- not enrolled",
            "  salle: caisse  -- caisse_makeen ... -- not enrolled",
            "",
            "Two real machines in a real deployment, neither enrolled yet, and the roll",
            "says so every time it is run rather than once in a document.",
        },
        .breakit = .{
            .proves = "that YOU can check this device's record, on your own machine, holding no secret",
            .then = EXE ++ " fleet zig-out\\fleet\\after.fleet verify temoin zig-out\\fleet\\fleet_temoin.journal",
            .expect = &.{
                "fleet atelier -- temoin: 1 entry verified against the enrolled key",
                "(fingerprint ........), and no secret took part",
                "",
                "Stop and look at what just happened. That record was signed by a key made",
                "inside a Linux machine running under QEMU, on a disk that no longer",
                "exists. You checked it from Windows, with this binary, holding one text",
                "file of sixty-four hex characters that the device published on its own",
                "console. The secret half never left the device and never will.",
                "",
                "The script left four files in zig-out\\fleet: the record, a TAMPERED copy",
                "of it, the fleet that enrolled the right key, and one that enrolled a",
                "different device's. Point them at each other and both negatives are",
                "yours to run:",
                "",
                "  " ++ EXE ++ " fleet zig-out\\fleet\\after.fleet verify temoin",
                "      zig-out\\fleet\\tampered.journal",
                "",
                "  -> the entry's own bytes do not hash to the hash it carries: it was",
                "     altered after it was written",
                "",
                "  " ++ EXE ++ " fleet zig-out\\fleet\\other.fleet verify temoin",
                "      zig-out\\fleet\\fleet_temoin.journal",
                "",
                "  -> this device's key did not sign this entry",
                "",
                "Right key, altered record -- against -- untouched record, wrong key. Two",
                "different wrongs, two different sentences, and the machine tells you",
                "WHICH. An auditor asking what happened needs that difference, and both",
                "commands exit 1 so a script asking gets it too.",
                "",
                "IF YOU WANT TO BREAK IT WITH YOUR OWN HANDS, open",
                "zig-out\\fleet\\after.fleet and change the LAST character of the 64 on",
                "the KEY line to anything else, then run the first command again. Same",
                "refusal as other.fleet gives, for the same reason.",
                "",
                "Do NOT copy a key out of this lesson or anywhere else. Yours is not the",
                "one in any example: the device makes a NEW key every time the script",
                "runs, because it builds a fresh disk and a key is made on first boot.",
                "Run the script twice and compare the KEY lines -- that is lesson 12's",
                "point arriving from the other side. A key survives the POWER; it does",
                "not survive the disk being thrown away.",
            },
            .note = "Nothing under zig-out is tracked by git, so there is nothing to check out: re-run the script and every file here is rebuilt (with a new key). The names above are stable even though the contents are not.",
        },
        .law = "A claim only its author can check is not evidence.",
        .story = "experiment/PROTOCOL.md (FLT-1)",
        .needs = &.{ "experiment/os7_fleet.sh", "machines/fleet_temoin.machine" },
    },

    // ---- V. the network ------------------------------------------------
    .{
        .act = "V. THE NETWORK",
        .title = "The box is the network's own server of names",
        .question = "The kitchen printer comes back on a different number after every power cut. Why should it?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os6_names.sh",
        .look = &.{
            "TWO machines boot at the same time on one QEMU wire, and then a THIRD",
            "run of the same till image with a different hardware address. Sixty-eight",
            "lines; here is what to find in them.",
            "",
            "The box, which declares who it serves and says so before anyone asks:",
            "",
            "  box: boot: names salle -- makeen: this machine is 192.168.10.1/24, 2",
            "  declared peers, and no address for anyone else",
            "  box: boot: names salle -- imprimante.makeen is 192.168.10.50 for",
            "  52:54:00:12:34:60",
            "  box: boot: names salle -- caisse.makeen is 192.168.10.40 for",
            "  52:54:00:12:34:61",
            "",
            "`no address for anyone else` is the whole design. There is no pool and no",
            "range. The register of who has which address IS the declaration, in git,",
            "judged before the image was built -- which is why it cannot be lost at a",
            "reboot, and why the printer comes back on the same number after a power cut.",
            "",
            "Look one line above those: `egress salle -- none: the machine knows no way",
            "off its own link`. The server of names is itself unable to reach anything",
            "beyond the wire, so when it says a name does not exist, that answer cannot",
            "have been fetched from anywhere. It is not a policy not to forward. There",
            "is nowhere to forward to.",
            "",
            "The till declares NO address, NO resolver and NO printer, and learns all",
            "three from the link:",
            "",
            "  till: boot: network salle -- eth0 up 192.168.10.40/24 (dhcp), dns",
            "  [192.168.10.1], names on makeen (/etc/resolv.conf)",
            "",
            "then asks FOUR questions, and the answers differ in a way worth reading",
            "slowly:",
            "",
            "  till: ask imprimante.makeen -- 192.168.10.50 (from 192.168.10.1)",
            "  till: ask imprimante        -- 192.168.10.50 (from 192.168.10.1)",
            "  till: ask makeen           -- 192.168.10.1  (from 192.168.10.1)",
            "  till: ask fantome.makeen   -- no such name on this network",
            "",
            "The second is the SHORT name: the till learned the domain as well as the",
            "resolver, so `imprimante` alone resolves. The third is the domain itself,",
            "which answers as the box. The fourth is a name nobody declared, and the",
            "answer is a flat refusal that never left the wire.",
            "",
            "Then the line the box prints when its own services are done, which is this",
            "seat's law in the machine's own words:",
            "",
            "  box: boot: every service has ended -- and this machine is still makeen: a",
            "  server stops when the machine stops, not when the asking does",
            "",
            "And last, the stranger -- the SAME image, booted with a hardware address",
            "nobody declared. It gets no lease, and every question comes back `no",
            "resolver: this machine was never told where to ask`. It does not hang, does",
            "not guess, and does not fall back to somebody else's resolver.",
            "",
            "Read its final three lines, because they are the only ones of their kind in",
            "this whole tour:",
            "",
            "  stranger: boot: judge -- the boot differs from its expectation",
            "  (/etc/expected): 1 line(s) expected and not said, 1 said and not expected",
            "  stranger: boot: judge -- expected, not said: network salle -- eth0 up *",
            "  stranger: boot: judge -- said, not expected: network salle -- eth0 dhcp:",
            "  no lease after 3 tries (no server answered on this network)",
            "",
            "That is a machine judging its OWN boot and convicting itself, naming both",
            "sides of the difference. Lesson 5 could not show you this -- editing a",
            "machine moves its expectation with it -- and sent you to the flagship. Here",
            "it is instead, and cleaner: nothing about the declaration changed. Only the",
            "wire did.",
        },
        .breakit = .{
            .proves = "that a device nobody declared gets nothing at all -- and is caught before it boots",
            .file = "machines\\salle_makeen.fleet",
            .where = "in the `caisse` member, on its HARDWARE line",
            .how = .replace,
            .paste = &.{
                "  HARDWARE \"52:54:00:99:99:99\"",
            },
            .then = EXE ++ " fleet machines\\salle_makeen.fleet",
            .expect = &.{
                "fleet (line 38): boitier promises no address to 52:54:00:99:99:99: a device",
                "that asks on salle and is in nobody's register will never get one, and no",
                "pool exists to fall back on",
                "",
                "You never had to boot anything. Because the register is a declaration and",
                "not a running server's memory, a device that would go unanswered on the",
                "wire is refused in a text file, months before the wire exists.",
                "",
                "Then run the two-machine script itself with that edit still in place. It",
                "stops in about two seconds, before it builds anything:",
                "",
                "  the fleet is refused, so there are no devices to be:",
                "  fleet (line 38): boitier promises no address to 52:54:00:99:99:99 ...",
                "",
                "That is the script reading the MACs out of the FLEET rather than carrying",
                "them as constants of its own (HDW-1), and then reading the verdict that",
                "comes with them. Until this lesson was run it read only whether the answer",
                "was EMPTY -- and a refused fleet does not answer empty, it prints its",
                "refusal -- so the script took the refusal TEXT as a hardware address,",
                "booted QEMU with a whole sentence for a MAC, and failed two minutes later",
                "saying `the box never said it was serving`. A symptom four steps from its",
                "cause.",
                "",
                "You do not need to boot it to see what a stranger gets: the `stranger`",
                "section of the clean run is exactly that case, already run for you.",
            },
            .undo = "git checkout -- machines/salle_makeen.fleet",
        },
        .law = "A machine that SERVES a link is not finished when its services are. No pool, no range -- the declaration IS the register.",
        .story = "experiment/PROTOCOL.md (NAM-1)",
        .needs = &.{ "experiment/os6_names.sh", "machines/makeen_names.machine", "machines/caisse_makeen.machine" },
    },
    .{
        .act = "V. THE NETWORK",
        .title = "Some facts are about a SET",
        .question = "Two machines are each faultless. Can the pair still be wrong?",
        .run = EXE ++ " fleet machines\\salle_makeen.fleet",
        .runnable = true,
        .look = &.{
            "fleet salle_makeen -- 2 members on salle, served by boitier -- judged, no",
            "refusal",
            "  boitier -- makeen_names (makeen_names.machine, 192.168.10.1/24, serves",
            "             makeen) -- 52:54:00:12:34:01 -- not enrolled",
            "  caisse  -- caisse_makeen (caisse_makeen.machine, asks) --",
            "             52:54:00:12:34:61, promised 192.168.10.40 as caisse --",
            "             not enrolled",
            "",
            "Three commands in this tour judge three different things, and it is worth",
            "being clear which is which. `stzos check` judges ONE machine. A boot judges",
            "what that machine DID. `stzos fleet` judges a SET, and nothing else can.",
            "",
            "Read what the roll derived rather than read. Nobody wrote `served by",
            "boitier` anywhere -- it worked that out from which member's machine declares",
            "a DOMAIN on salle. Nobody wrote `asks` against caisse -- that is its",
            "declaration saying ADDRESS dhcp. And `promised 192.168.10.40 as caisse` is",
            "the box's PEER declaration and the till's MEMBER entry agreeing, which is a",
            "fact that exists in neither file alone.",
            "",
            "Then the two words at the end of both lines: `not enrolled`. That is lesson",
            "14 from the other side. These are two real machines in a real deployment,",
            "neither of whose records anyone could verify yet, and the roll says so every",
            "single time it is called rather than once in a document somebody has to",
            "remember to read.",
        },
        .breakit = .{
            .proves = "that a mistake can live between two files, in neither of them",
            .file = "machines\\_second_box.machine  (it does not exist yet)",
            .where = "this break is two edits -- a whole new machine file, and then three lines added to the end of machines\\salle_makeen.fleet. Both are below, in that order.",
            .how = .create,
            .paste = &.{
                "DEFINE MACHINE deuxieme_boitier AS (",
                "  PROFILE hosted,",
                "  ARCH x86_64,",
                "  KERNEL linux",
                ") RATIONALE \"A second box, faultless on its own\"",
                "",
                "DEFINE CAPABILITY network AS (",
                "  GRANT yes",
                ") RATIONALE \"It speaks\"",
                "",
                "DEFINE NETWORK salle AS (",
                "  INTERFACE \"eth0\",",
                "  ADDRESS \"192.168.10.2/24\",",
                "  DOMAIN \"makeen\"",
                ") RATIONALE \"And it, too, calls itself the server of this link\"",
                "",
                "-- then add these three lines to the END of machines\\salle_makeen.fleet:",
                "",
                "DEFINE MEMBER deuxieme AS (",
                "  DECLARATION \"_second_box.machine\"",
                ") RATIONALE \"A second box that also calls itself the server of salle\"",
            },
            .then = EXE ++ " fleet machines\\salle_makeen.fleet",
            .expect = &.{
                "fleet (line 43): boitier already serves salle: one link, one server of",
                "names, or two machines hand out the same addresses and neither is wrong",
                "alone",
                "",
                "Now judge that new box entirely on its own:",
                "",
                "  " ++ EXE ++ " check machines\\_second_box.machine",
                "  machine deuxieme_boitier -- ... judged, no refusal",
                "",
                "It PASSES. Now check the box it collides with, which has been in this",
                "repository all along:",
                "",
                "  " ++ EXE ++ " check machines\\makeen_names.machine",
                "  machine makeen_names -- ... judged, no refusal",
                "",
                "It passes too. Two files, each faultless, describing together a network",
                "where two machines hand out the same addresses. No amount of care spent",
                "on either file could have caught it, because the mistake is not IN either",
                "file. Only a file about the SET can see it.",
                "",
                "And this is a category, not one clever rule. ELEVEN of the fleet",
                "grammar's eighteen refusals are of this kind -- visible only across",
                "members, never inside one file. They are named in",
                "declarative/fleet/fixtures.json; among them:",
                "",
                "  one address, one machine",
                "  one device, one member",
                "  two members cannot be the same machine",
                "  a link with somebody asking and nobody serving",
                "  an address the server has promised to somebody is not free to take",
                "  a device cannot be promised one address and take another",
                "  the server is not one of the devices it serves",
                "",
                "Read those seven as sentences about a restaurant rather than a grammar.",
                "Every one of them is a way for a room full of correctly-configured boxes",
                "to be a broken network on Monday morning.",
            },
            .undo = "del machines\\_second_box.machine  and then  git checkout -- machines/salle_makeen.fleet",
        },
        .law = "Some facts are about a SET and belong in a file about a set.",
        .story = "declarative/fleet/GRAMMAR.md",
        .needs = &.{ "machines/salle_makeen.fleet", "machines/makeen_names.machine", "declarative/fleet/fixtures.json", "declarative/fleet/GRAMMAR.md" },
    },

    // ---- VI. the flagship ----------------------------------------------
    .{
        .act = "VI. THE FLAGSHIP",
        .title = "The Makeen box: four boots, three cards, and a verdict it refused to commit",
        .question = "A box in a restaurant takes an update at two in the morning and it is wrong. Then what?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh makeen_box",
        .look = &.{
            "129 lines, four boots, and they are NOT four boots of one card. Check the",
            "fingerprints and the labels:",
            "",
            "  section   what its identity line says        what it is",
            "  -------   ------------------------------     ---------------------",
            "  boot:     created ... fingerprint KEY1        the trial",
            "  steady:   already ... fingerprint KEY1        the SAME card again",
            "  hold:     created ... fingerprint KEY2        a PRISTINE card",
            "  unmet:    created ... fingerprint KEY3        another pristine card",
            "",
            "Three cards. KEY1 appears twice because that card kept its key across a",
            "power cycle, which is lesson 12's whole claim; KEY2 and KEY3 are different",
            "because a new card is a new device. The court maps each DISTINCT fingerprint",
            "to KEY1, KEY2, KEY3 rather than blanking them, which is the only reason any",
            "of this is visible.",
            "",
            "Now the instrument. An update arrives; the box boots it in the OTHER slot as",
            "a trial, and must earn the right to keep it:",
            "",
            "  boot: slot B -- a trial (committed is A); the watchdog holds the rollback",
            "        until the boot is judged",
            "  boot: slot B -- committed: every service is ready and has held its health",
            "        window and the boot matches its expectation; config.txt now boots B,",
            "        A is the fallback",
            "",
            "Read that as the conjunction it is: ready, AND held its window, AND matched.",
            "All three, or no commit. Then the part to read most",
            "carefully, because it is the only evidence that any of this was real:",
            "",
            "  card: config.txt after the trial:",
            "  card: os_prefix=slots/B/",
            "  card: [tryboot]",
            "  card: os_prefix=slots/A/",
            "",
            "That is the actual file on the actual card. B is what boots now; A is what",
            "the firmware falls back to. The commit is not a log line claiming a commit --",
            "it is four lines of a file, printed so you can check them.",
            "",
            "Compare that block against the same block after the other two trials. Both",
            "read `os_prefix=slots/A/` first. The card still boots the OLD slot. Nothing",
            "was kept.",
            "",
            "And the `unmet:` boot is the one to read twice. It is the same trial judged",
            "against the BOARD's expectation instead of the emulator's, so the emulator's",
            "missing hardware shows up as a difference -- and the box names all four",
            "sides of it:",
            "",
            "  unmet: boot: judge -- the boot differs from its expectation",
            "         (/etc/expected): 2 line(s) expected and not said, 2 said and not",
            "         expected",
            "  unmet: boot: judge -- expected, not said: network lan -- eth0 up",
            "         192.168.10.1/24",
            "  unmet: boot: judge -- expected, not said: watchdog armed (/dev/watchdog)",
            "  unmet: boot: judge -- said, not expected: network lan -- eth0: no such",
            "         interface (NODEV)",
            "  unmet: boot: judge -- said, not expected: watchdog -- off by the boot line",
            "         (the emulator resets on arming); a trial cannot roll back by",
            "         hardware here",
            "",
            "then writes that verdict into its own signed record:",
            "",
            "  unmet: boot: journal -- /data/boot.journal: the chain begins, entry 1",
            "         signed by this device (verdict differed)",
            "",
            "and refuses to keep the update:",
            "",
            "  unmet: boot: slot B -- held: every service is ready but the boot is not",
            "         the one expected; not committed, the watchdog is no longer fed --",
            "         the next boot is A",
            "",
            "Every service was ready. Both worlds were serving. And it still refused,",
            "because readiness was never the test -- the test is whether the boot is the",
            "DECLARED one. That is the line an auditor wants, and the line a vendor's box",
            "would never keep about itself.",
        },
        .breakit = .{
            .proves = "that the transcript already carries its own negative",
            .note = "Nothing to edit: this machine needs an SD card and a board to be broken properly, and the transcript already carries three negatives of its own. Read them as a set. `hold:` is a trial that passes every check and is deliberately not committed -- the rollback instrument proving it can decline. `unmet:` is a trial that passes every check EXCEPT the verdict, and declines by itself. And `boot: refuse gpio (effectful)` near the top is a capability the machine DECLARED and the profile refused, said out loud rather than dropped. Two honesty lines are worth noticing while you are there: `watchdog -- off by the boot line (the emulator resets on arming)` and `--halt-on-verdict: the court ends what a real init never would`. The emulator cannot do two things this box depends on, and the transcript says which, rather than quietly pretending otherwise -- which is why OS-5 waits on hardware.",
        },
        .law = "A trial commits only on a match, and no expectation is no commit.",
        .story = "declarative/machine/PINNING.md",
        .needs = &.{ "machines/makeen_box.machine", "machines/makeen_box.expected", "experiment/os2_image.sh" },
    },
    .{
        .act = "VI. THE FLAGSHIP",
        .title = "The four standing promises, judged by name",
        .question = "What does this floor actually promise a merchant, and can the promise be checked?",
        .run = "wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/judge_guarantees.sh",
        .look = &.{
            "The four promises of the hosted profile -- always reachable, a stable name, a",
            "durable log, survives the cut -- each judged KEPT or NOT against the box's own",
            "transcript. Twice: once through what the board should say, once through what",
            "the emulator can actually show.",
        },
        .breakit = .{
            .proves = "that a judge can convict itself, which this one once did",
            .note = "The judge reads ONLY lines that begin `boot: ` and are not `boot: judge --`. Before that it searched the whole transcript, and found the words it was looking for INSIDE the sentence that denied them -- reporting a promise as kept by quoting the line that said it was missing. Evidence is what the machine said about this boot, never what it quoted about another.",
        },
        .law = "Evidence is what the machine said about THIS boot, never what it quoted about another.",
        .story = "experiment/PROTOCOL.md (GRT-1)",
        .needs = &.{"experiment/judge_guarantees.sh"},
    },
};

fn rule(w: *std.Io.Writer) !void {
    try w.print("  {s}\n", .{"-" ** 70});
}

/// An indented block, where a blank line stays blank rather than
/// becoming nine spaces nobody can see.
fn block(w: *std.Io.Writer, pad: []const u8, lines: []const []const u8) !void {
    for (lines) |line| {
        if (line.len == 0) try w.print("\n", .{}) else try w.print("{s}{s}\n", .{ pad, line });
    }
}

pub fn list(w: *std.Io.Writer) !void {
    try w.print("\n  stzos learn -- a guided tour of a declared machine, in {d} lessons.\n", .{lessons.len});
    try rule(w);
    try w.print("  BEFORE YOU START\n", .{});
    try w.print("    Run everything from the repository root, D:\\GitHub\\stzos, so that a\n", .{});
    try w.print("    path like machines\\qemu_hello.machine means what the lesson thinks.\n", .{});
    try w.print("    That stays true even with this binary on your PATH: the lessons spell\n", .{});
    try w.print("    it {s}, and if you can type just `stzos`\n", .{EXE});
    try w.print("    then do -- but still from the root, because the MACHINE paths are\n", .{});
    try w.print("    relative and the command name no longer tells you where to stand.\n", .{});
    try w.print("    New to the words? {s} learn --words\n\n", .{EXE});
    var act: []const u8 = "";
    for (lessons, 1..) |l, i| {
        if (!std.mem.eql(u8, act, l.act)) {
            act = l.act;
            try w.print("  {s}\n", .{act});
        }
        try w.print("   {d:>2}  {s}\n", .{ i, l.title });
    }
    try w.print("\n  {s} learn <n>          one lesson, in full\n", .{EXE});
    try w.print("  {s} learn <n> --run    and run its command for you\n", .{EXE});
    try w.print("  {s} learn --all        every lesson, in order\n", .{EXE});
    try w.print("  {s} learn --words      what a world, a pin and a court are\n\n", .{EXE});
}

/// Greedy wrap at 72 columns. The glossary is prose rather than a
/// transcript, so it is the one place here where a line's length is the
/// terminal's business and not the machine's.
fn wrapped(w: *std.Io.Writer, pad: []const u8, text: []const u8) !void {
    var it = std.mem.tokenizeScalar(u8, text, ' ');
    var col: usize = 0;
    while (it.next()) |word| {
        if (col == 0) {
            try w.print("{s}{s}", .{ pad, word });
            col = word.len;
        } else if (col + 1 + word.len > 72) {
            try w.print("\n{s}{s}", .{ pad, word });
            col = word.len;
        } else {
            try w.print(" {s}", .{word});
            col += 1 + word.len;
        }
    }
    try w.print("\n", .{});
}

pub fn glossary(w: *std.Io.Writer) !void {
    try w.print("\n  The words this tour uses, in the order you meet them.\n", .{});
    try rule(w);
    for (words) |pair| {
        try w.print("\n  {s}\n", .{pair[0]});
        try wrapped(w, "    ", pair[1]);
    }
    try w.print("\n", .{});
}

/// The pin that will refuse this break's boot, or null if the step does
/// not boot an edited machine. Derived from what the step already knows
/// -- the file it edits and the command it runs -- rather than written
/// out in each lesson, because six lessons need it and a seventh will be
/// written by somebody who has forgotten.
fn pinStem(b: Break) ?[]const u8 {
    const suffix = ".machine";
    if (!std.mem.endsWith(u8, b.file, suffix)) return null;
    if (std.mem.indexOf(u8, b.then, "os2_image.sh") == null) return null;
    return b.file[0 .. b.file.len - suffix.len];
}

/// The same pin as a repository path, for `--check` to walk: the lessons
/// spell Windows paths and the judge needs a real one.
fn pinPath(b: Break, buf: []u8) ?[]const u8 {
    const stem = pinStem(b) orelse return null;
    const ext = ".expected";
    if (stem.len + ext.len > buf.len) return null;
    @memcpy(buf[0..stem.len], stem);
    @memcpy(buf[stem.len..][0..ext.len], ext);
    const out = buf[0 .. stem.len + ext.len];
    for (out) |*c| {
        if (c.* == '\\') c.* = '/';
    }
    return out;
}

fn renderBreak(w: *std.Io.Writer, b: Break) !void {
    if (b.proves.len + "  BREAK IT -- to prove ".len <= 76) {
        try w.print("  BREAK IT -- to prove {s}\n", .{b.proves});
    } else {
        try w.print("  BREAK IT -- to prove\n", .{});
        try wrapped(w, "    ", b.proves);
    }
    var step: usize = 1;
    if (b.file.len > 0) {
        try w.print("\n    {d}. {s}\n", .{ step, switch (b.how) {
            .create => "Create this file:",
            else => "Open this file in an editor:",
        } });
        try w.print("         {s}\n", .{b.file});
        step += 1;
        if (b.where.len > 0) {
            try w.print("\n    {d}. Find the place:\n", .{step});
            try wrapped(w, "         ", b.where);
            step += 1;
        }
    }
    if (b.paste.len > 0) {
        try w.print("\n    {d}. {s}\n\n", .{ step, switch (b.how) {
            .append => "Add this there, exactly as it is written:",
            .replace => "REPLACE that line with this one:",
            .create => "Put this in it, all of it:",
        } });
        try block(w, "         ", b.paste);
        step += 1;
    }
    if (b.then.len > 0) {
        try w.print("\n    {d}. Run:\n         {s}\n", .{ step, b.then });
        step += 1;
    }
    if (b.expect.len > 0) {
        try w.print("\n    {d}. You should see:\n\n", .{step});
        try block(w, "         ", b.expect);
        step += 1;
    }
    // Derived, never written per lesson, because it was FORGOTTEN once
    // and once is how you learn it will be forgotten again: a boot of a
    // machine you have edited ALWAYS ends with the pin refusing the
    // transcript, and that is the loudest thing on the reader's screen.
    // The first reader of this tour ran lesson 5, got the line the
    // lesson promised, and then got a FAIL underneath it that the lesson
    // had never mentioned.
    if (pinStem(b)) |stem| {
        try w.print("\n    {d}. AND THEN A FAILURE, WHICH IS CORRECT:\n\n", .{step});
        try w.print("         JUDGED: FAIL -- the transcript differs from {s}.expected:\n", .{stem});
        try block(w, "         ", &.{
            "  ... followed by a diff of every line you changed.",
            "",
            "Do not be alarmed, and do not undo anything yet. TWO different judges",
            "ran. The first is the machine judging ITSELF, above: its expectation is",
            "derived from the declaration, so when you edit the machine both sides",
            "move together and it still matches. The second is the PIN -- a stored",
            "copy of what a RIGHT boot of this machine says, which does not move,",
            "because somebody committed it deliberately. You changed the machine, so",
            "the pin is now describing a different machine, and it says so.",
            "",
            "That is lesson 6 arriving early, and it is the whole reason both judges",
            "exist. The undo below makes it match again.",
        });
        step += 1;
    }
    if (b.undo.len > 0) {
        try w.print("\n    {d}. Put everything back exactly as it was:\n         {s}\n", .{ step, b.undo });
    }
    if (b.note.len > 0) {
        try w.print("\n", .{});
        try wrapped(w, "    ", b.note);
    }
    try w.print("\n", .{});
}

pub fn one(w: *std.Io.Writer, n: usize) !void {
    const l = lessons[n - 1];
    try w.print("\n  Lesson {d} of {d} -- {s}\n", .{ n, lessons.len, l.act });
    try rule(w);
    try w.print("  {s}\n\n", .{l.title});
    try w.print("  THE QUESTION\n", .{});
    try wrapped(w, "    ", l.question);
    // a lesson whose evidence is inside another lesson's run says so,
    // rather than printing a sentence underneath the word RUN
    if (l.run[0] == '(') {
        try w.print("\n  WHERE TO SEE IT\n", .{});
        try wrapped(w, "    ", l.run[1 .. l.run.len - 1]);
        try w.print("\n", .{});
    } else {
        try w.print("\n  RUN  (from D:\\GitHub\\stzos)\n    {s}\n\n", .{l.run});
    }
    try w.print("  LOOK FOR\n", .{});
    try block(w, "    ", l.look);
    try w.print("\n", .{});
    try renderBreak(w, l.breakit);
    try w.print("  THE LAW IT PAID FOR\n", .{});
    try wrapped(w, "    ", l.law);
    try w.print("\n", .{});
    try w.print("  THE FULL STORY\n    {s}\n\n", .{l.story});
}

pub fn all(w: *std.Io.Writer) !void {
    for (lessons, 1..) |_, i| try one(w, i);
}

/// Walk every path a lesson names. A curriculum that points at a machine
/// somebody renamed is a tutorial that lies, and this is what stops it:
/// `zig build court` runs this, so the lie fails in the commit that made
/// it rather than the first time a reader tries to follow along.
/// Prefixes that mark a line as something a MACHINE said, rather than
/// the tour's own prose. A lesson may paraphrase freely; what it
/// presents as a quotation has to be one.
const said_prefixes = [_][]const u8{
    "boot:",     "again:",  "steady:",    "hold:",      "unmet:",
    "card:",     "box:",    "till:",      "stranger:",  "confined:",
    "attest:",   "journal", "kds:",       "poste:",     "modest:",
    "swarm:",    "greedy:", "reach ",     "ask ",       "device:",
    "roll:",     "verify:", "tampered:",  "foreign:",   "unenrolled:",
    "salle:",    "carried:",
};

fn looksSaid(line: []const u8) bool {
    const t = std.mem.trim(u8, line, " ");
    for (said_prefixes) |p| {
        if (std.mem.startsWith(u8, t, p)) return true;
    }
    return false;
}

/// Append `text` to `out` with every run of whitespace collapsed to one
/// space, so the tour's hand-wrapping cannot make a quote look different
/// from the single long line a pin holds.
fn flatten(out: *std.ArrayList(u8), alloc: std.mem.Allocator, text: []const u8) !void {
    var space = false;
    for (text) |c| {
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
            space = true;
            continue;
        }
        if (space and out.items.len > 0) try out.append(alloc, ' ');
        space = false;
        try out.append(alloc, c);
    }
}

/// Every machines/*.expected, flattened into one haystack.
fn pinHaystack(alloc: std.mem.Allocator) ![]u8 {
    var hay: std.ArrayList(u8) = .{};
    var dir = try std.fs.cwd().openDir("machines", .{ .iterate = true });
    defer dir.close();
    var it = dir.iterate();
    while (try it.next()) |e| {
        if (e.kind != .file) continue;
        if (!std.mem.endsWith(u8, e.name, ".expected")) continue;
        const text = try dir.readFileAlloc(alloc, e.name, 1 << 22);
        defer alloc.free(text);
        try flatten(&hay, alloc, text);
        try hay.append(alloc, '\n');
    }
    return hay.toOwnedSlice(alloc);
}

pub fn check(w: *std.Io.Writer) !usize {
    var missing: usize = 0;
    var buf: [256]u8 = undefined;
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const alloc = arena_state.allocator();
    const hay = try pinHaystack(alloc);
    for (lessons, 1..) |l, i| {
        for (l.needs) |p| {
            std.fs.cwd().access(p, .{}) catch {
                missing += 1;
                try w.print("  lesson {d} names {s}, which is not there\n", .{ i, p });
            };
        }
        // the pin the lesson promises will refuse the boot is a path the
        // lesson NAMES, even though no lesson wrote it down
        if (pinPath(l.breakit, &buf)) |pin| {
            std.fs.cwd().access(pin, .{}) catch {
                missing += 1;
                try w.print("  lesson {d} promises a refusal from {s}, which is not there\n", .{ i, pin });
            };
        }

        // EVERY LINE A LESSON QUOTES MUST BE A LINE A MACHINE SAID.
        //
        // The paths were checked from the first day and the quotations
        // never were, which is the larger claim of the two: a reader
        // comparing their screen against the lesson is comparing it
        // against these strings. Dropping a `boot: ` prefix or a
        // `/data/boot.journal: ` path to make a line fit turns a
        // quotation into a paraphrase wearing quotation's clothes, and
        // that had happened in four lessons before anything looked.
        //
        // Only LOOK FOR is checked. A BREAK IT's `expect` is what the
        // reader sees AFTER changing the machine, so no pin can hold it.
        var j: usize = 0;
        while (j < l.look.len) : (j += 1) {
            if (!looksSaid(l.look[j])) continue;
            var quote: std.ArrayList(u8) = .{};
            defer quote.deinit(alloc);
            try flatten(&quote, alloc, l.look[j]);
            // join the continuation lines the tour wrapped by hand
            var k = j + 1;
            while (k < l.look.len and l.look[k].len > 2 and
                std.mem.startsWith(u8, l.look[k], "  ") and !looksSaid(l.look[k])) : (k += 1)
            {
                // no explicit space: the continuation begins with the
                // tour's own indent, and flatten turns that into exactly
                // one separator
                try flatten(&quote, alloc, l.look[k]);
            }
            const q = std.mem.trim(u8, quote.items, " ");
            // short fragments and deliberate elisions are not claims
            if (q.len < 25) continue;
            if (std.mem.indexOf(u8, q, "...") != null) continue;
            if (std.mem.indexOf(u8, hay, q) == null) {
                missing += 1;
                try w.print("  lesson {d} quotes a line no pin holds:\n    {s}\n", .{ i, q });
            }
            j = k - 1;
        }
    }
    if (missing == 0) {
        try w.print("learn -- {d} lessons: every path they name is present, and every line they quote is a line a machine said\n", .{lessons.len});
    } else {
        try w.print("learn -- {d} claim(s) a lesson makes do not hold\n", .{missing});
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
        try t.expect(l.law.len > 0 and l.story.len > 0);
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

test "a BREAK IT step never leaves the reader to guess" {
    const t = std.testing;
    for (lessons) |l| {
        const b = l.breakit;
        try t.expect(b.proves.len > 0);
        // an edit must say WHERE, what to type, and how to put it back --
        // the first reader of this tour had to work all three out, and
        // that is the defect this test exists to keep fixed
        if (b.file.len > 0) {
            try t.expect(b.where.len > 0);
            try t.expect(b.paste.len > 0);
            try t.expect(b.then.len > 0);
            try t.expect(b.expect.len > 0);
            // the undo must actually RESTORE, not just describe -- the
            // first reader was left with a dirty working tree because
            // lesson 1 never told them how to put the file back
            try t.expect(std.mem.indexOf(u8, b.undo, "git checkout -- ") != null);
        } else {
            // nothing to edit: then it owes the reader an explanation
            try t.expect(b.note.len > 0);
        }
    }
}

test "a step that boots an edited machine warns about the pin it will fail" {
    const t = std.testing;
    var buf: [256]u8 = undefined;
    var warned: usize = 0;
    for (lessons) |l| {
        const b = l.breakit;
        const boots = std.mem.indexOf(u8, b.then, "os2_image.sh") != null;
        const edits_machine = std.mem.endsWith(u8, b.file, ".machine");
        // the warning is DERIVED, so the only way to get it wrong is for
        // the derivation to stop firing: assert it fires exactly when a
        // reader would see JUDGED: FAIL and nowhere else
        try t.expectEqual(boots and edits_machine, pinStem(b) != null);
        if (pinPath(b, &buf)) |pin| {
            warned += 1;
            try t.expect(std.mem.startsWith(u8, pin, "machines/"));
            try t.expect(std.mem.endsWith(u8, pin, ".expected"));
            try t.expect(std.mem.indexOfScalar(u8, pin, '\\') == null);
        }
    }
    // lessons 4, 5, 7, 9, 10 and 11 all edit a pinned machine and boot it
    try t.expectEqual(@as(usize, 6), warned);
}

test "a lesson that can be run names this binary" {
    const t = std.testing;
    for (lessons) |l| {
        if (!l.runnable) continue;
        try t.expect(std.mem.startsWith(u8, l.run, EXE));
    }
}
