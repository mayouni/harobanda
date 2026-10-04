# pack v0.1 — the grammar of what a solution asks, and where it is placed

## Why there is a third file and not a bigger one

A machine file says what ONE machine is, and what it grants. A fleet
file says what a SET of machines is. Neither can say what a SOLUTION
is: the services it runs, the identities they run as, and what each of
them needs from whatever machine it lands on. Those facts are written
once, by the people who made the solution, and they must be placeable
on a machine somebody else declared: a box in a restaurant, a server
in a bank, a virtual machine somebody rents.

It is the **same language** — the same tokenizer, the same clause
machinery, the same refusal channel, the same mandatory `RATIONALE`.
A file is judged by which kinds it may contain, as the fleet file's
rule is: a pack may carry `SERVICE` and `USER` and nothing else.

## A pack asks, and the machine grants

Everything a world may use is the machine's to say: its capabilities,
its mounts, its networks, its pins. A pack that could declare a
`CAPABILITY` would grant itself what it asks for, and the grant would
mean nothing. So a pack names what its services NEED, which mounts
they SEE and which user they run as, and the machine it is placed on
either has those or refuses the placement, at the line of the pack
that asked.

| kind | whose it is | in a pack |
|---|---|---|
| `SERVICE` | the solution's | the point of the file |
| `USER` | the solution's identity, its number checked against the machine's | allowed |
| `MACHINE` | the machine the pack is placed on | refused (PR2) |
| `CAPABILITY` | the machine: what a world may use is its to say | refused (PR3) |
| `MOUNT` | the machine: which storage exists | refused (PR4) |
| `NETWORK` | the machine: how it reaches the wire | refused (PR5) |
| `FLEET`, `MEMBER`, `RETIREMENT` | a fleet file | refused (PR6) |

`PEER` and `PIN` are refused by the same line of code as the others;
no case of their own was written.

## One reading of the rules

A pack alone is judged only for what a pack IS: its kinds and its
names. Whether a service's `NEEDS` are granted, whether its `READY`
path is free, whether its `AFTER` resolves, whether its `RUN` is a
shell: those are the machine court's rules, and a pack's services are
judged by them in the only place they mean anything, on a machine.
`harb place` does not copy a rule. It composes ONE machine text out of
the machine file and the packs, hands it to the one court, and says
where each refusal came from. A pack is therefore tried on a host: the
smallest machine that grants what the pack asks is its author's test
bench.

## Placement

`harb place <file.machine> <file.pack>... [--out <file>]`, in this
order:

1. **The machine is judged alone.** A machine the court refuses is
   refused as the machine, before anything is placed on it (PR12), so
   a refusal that comes later is known to come from the placement.
2. **Each pack is read alone**: its kinds (PR2–PR6), at least one
   `SERVICE` (PR1, PR7), and its own names (PR8).
3. **The names are one namespace across the machine and every pack,
   kind-blind**, as the machine court's own rule is: a pack service
   may not take a service's name (PR9), a capability's (PR10), the
   machine's own (PR23), or one an earlier pack took (PR11). The
   refusal names the file and the line that took it first.
4. **One text is composed**: the machine file as written, then each
   pack as written in the order given, each under a one-line comment
   naming the pack and its sha256.
5. **The machine court judges that text**, and a refusal is reported
   at the file and the line, in that file's own numbering, that wrote
   it (PR14–PR22, PR24).

Without `--out` it is a rehearsal: judged, nothing written. With it,
the placed text is written, and it is a machine file like any other:
`harb check`, `plan`, `image` and `judge` take it.

## Where a refusal is reported

`place: <file> (line N): <message>`, where the file is a file NAME and
the line is the line of that file. A line number in a text the reader
did not write is not an answer, so the placed text's own numbering is
never shown. A refusal that lands in the machine's own lines after the
machine passed alone says so: *the machine passes alone; this arose
when the packs were placed on it*. No rule of the machine court
produces one today; the mapping is judged beside the code
(`src/pack.zig`) so that the first such rule does not mislead.

## Reproducible

The placed text is a function of the bytes it was given and the order
of the packs, and of nothing else: no path is written into it, only
file names, and the banner carries the pack's sha256. Placing twice
gives the same bytes, on any machine. The machine file's own digest in
a machine's journal (`init.zig`) then names the pack that ran as well
as the machine.

## A worked example

A machine that grants what a solution usually asks:

```
DEFINE MACHINE core AS (
  PROFILE hosted,
  ARCH x86_64,
  KERNEL linux
) RATIONALE "The machine a solution is placed on"

DEFINE CAPABILITY network AS (
  GRANT yes
) RATIONALE "A solution serves on the network"

DEFINE CAPABILITY filesystem AS (
  GRANT yes
) RATIONALE "Its data lives on a declared mount"

DEFINE MOUNT data AS (
  AT "/data",
  FS tmpfs,
  OPTIONS [rw]
) RATIONALE "Where the solution keeps what it keeps"
```

and a pack that asks for it:

```
DEFINE USER commons_user AS (
  UID 2001
) RATIONALE "The Commons owns nothing of the machine"

DEFINE SERVICE commons AS (
  RUN ["/stzr", "/app/commons.luau"],
  RESTART always,
  READY "/run/commons.ready",
  NEEDS [network, filesystem],
  SEES [data],
  USER commons_user
) RATIONALE "Catalogue, orders and payments"
```

placed, with the result written:

```
zig-out\bin\harb.exe place core.machine commons.pack `
  --out placed\core.machine
place commons.pack (sha256 7ab21f4b5a2a742f) -- 1 service(s),
    1 user(s)
on machine core -- hosted / x86_64 / kernel linux -- 1
    service(s) in all -- judged, no refusal
written placed\core.machine (sha256 1f20cbb045b6c552): harb
    check, plan, image and judge take it as any machine
```

The digests are those of the two files above, as shown. Placed on a
machine that grants no network, the same pack is refused at its own
line:

```
place: commons.pack (line 9): commons needs network, which no
    declaration grants
```

## The checks

Every reject in `fixtures.json` carries the file and the line it must
name, and the fragment it must contain.

| id | refused |
|---|---|
| PR1 | a pack that declares nothing |
| PR2 | a `MACHINE` in a pack |
| PR3 | a `CAPABILITY` in a pack: it would grant itself what it asks for |
| PR4 | a `MOUNT` in a pack |
| PR5 | a `NETWORK` in a pack |
| PR6 | a `FLEET` in a pack |
| PR7 | a pack of identities alone: it places nothing |
| PR8 | a name declared twice in one pack |
| PR9 | a pack service with the name of one of the machine's services |
| PR10 | a pack identity with the name of a capability: one namespace across every kind |
| PR11 | the same name in two packs: the second is refused and names the first |
| PR12 | a machine refused on its own, before anything is placed on it |
| PR13 | nothing to place |
| PR14 | a need the machine does not grant, at the pack's `NEEDS` line |
| PR15 | a need the machine declared and refused |
| PR16 | a mount the pack `SEES` that the machine never declared |
| PR17 | an `AFTER` naming a service nobody declared |
| PR18 | a `USER` nobody declared |
| PR19 | a pack identity taking a number the machine already gave out |
| PR20 | a `READY` path the machine's own service already signals on |
| PR21 | a shell on the boot path, smuggled in by a pack |
| PR22 | services of one pack that come after each other: a cycle |
| PR23 | a pack service with the machine's own name |
| PR24 | a pack the language cannot read, refused in its own numbering |

PA1–PA6 are the accepts: an identity, a budget and a health window
placed on a machine that grants them (PA1); the smallest solution
(PA2); two packs, the second after a service of the first (PA3); a
machine that declares only itself (PA4); an identity beside the
machine's own, each keeping its number (PA5); the order the packs are
given, and `AFTER`, not position, ordering a boot (PA6).

## Named seams (stated, not hidden)

- **A solution's own declaration does not project into a pack.** The
  projection stzp's server target would make is not written; a pack
  is hand-written today.
- **A service has no port and no reach of its own.** The pack cannot
  say which port a world serves on or which destinations it may
  reach: a world has the machine's network when it `NEEDS` it, and a
  machine's reach is per `NETWORK` until it is per world (`doc/CLOUD.md`,
  rung 6). So two packs whose servers listen on one port are judged
  fine and collide at boot (SRV-2).
- **A fleet does not name packs yet.** A `MEMBER` that says which
  packs it runs is the grammar's next widening; today `harb place` is
  run by hand and its output is the machine file a member names.
- **`place` judges the declaration and stages nothing.** The programs
  a pack's `RUN` names must be in the image's root when `harb image`
  runs, as for any machine. For the first real server (SRV-2) a list of
  `<file> <destination>` lines, read by `experiment/os2_image.sh`, puts
  them there: a script's convention, and not a clause of the pack.
- **A pack cannot say when its server is serving.** A program that
  writes no READY path is run through `harb ready`, which the pack's
  own `RUN` names (`machines/ringserv.pack`); a world with a `USER`
  cannot create that path in `/run`, which is root's.
- **The pack's own digest is recorded, not the programs it names.**
- **The tour does not teach it yet**, and "a pack" is not one of its
  words.

## Conformance

`declarative/pack/fixtures.json`, pinned by sha256 in `PINNING.md`
beside it, judged by `zig build court` (which runs all three grammars)
or `harb court --pack`. Every reject carries the fragment its refusal
must contain AND the file and line it must name, so a runtime that
refuses for the wrong reason, or points at the wrong place, fails.
