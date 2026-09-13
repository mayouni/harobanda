# The Dividend — what owning the floor gives each layer above it

*2026-09-13. The author's question: "what would an application server
like RingServ or stzAppServer benefit when we own not only the server
but also the OS? Same for all the other tools and features: Ring++
(the future Haro), PI (Programmatic Intelligence) and the other
intelligence and natural modules, etc." This document answers it layer
by layer. For each layer: what it is today, cited; what it silently
borrows from a vendor's operating system today; what the declared
machine gives it; what it owes the floor in return; and whether the
seam is real, by design, or queued. Companion of `GROUND.md` (what the
machine is for). Unratified: an analysis, not a ruling.*

## 1. The method: find the borrowed floor

Every layer of the estate was written on a floor it did not own, and
each carries the marks. A server binds a port and hopes nothing else
is listening. A runtime loads a library and hopes the loader agrees. A
page stores its data under an origin and hopes the origin does not
move. An intelligence module loads a model and hopes there is memory.
Each of those hopes is code: an `if` about the environment, a retry, a
fallback, a configuration file, a log line nobody reads. The dividend
of owning the floor is that every one of those hopes becomes a line
the machine declares, judges before boot and proves in its transcript,
and the code that hoped can be deleted.

So the accounting below is the same for every layer: the hopes it
carries today, the lines that replace them, and the obligation it
takes on, which is always the same obligation: declare what you need,
in your own closed grammar, so the floor can grant it and judge it.

## 2. Eight dividends every layer inherits

These come with the floor itself, before any layer is named. Each is
either already shown by the three machines that boot in the emulator,
or a seam named in `ARCHITECTURE.md` §7.

| dividend | what it means one floor up | status |
|---|---|---|
| **The floor is a fact, not a hope** | every mount, address, identity and service order a layer needs is declared, planned, and in the transcript before the layer's first line runs; discovery code and environment `if`s go | real: three machines, pinned transcripts |
| **The envelope is below the runtime** | a CAPABILITY refused is a thing the world cannot do; today the runtime refuses it (down-constrain), tomorrow the kernel does, derived from the same line (namespaces, allowed system calls, budgets) | real at the runtime; queued at the kernel |
| **Identity from the floor** | a world runs as a declared USER or as the machine, and uid 0 cannot be declared; a per-device key that never leaves the board is the next fact | real (USR-1); the device key queued |
| **Time and the journal** | a persistent partition mounted before any world speaks, with declared options; the clock a capability; a signed, never-trimmable journal a named seat | real for the mount; the journal seat named |
| **One narrative** | every world's output is a line in the machine's transcript, in a stable grammar with a stable prefix; no syslog, no journald; an agent reads facts, a person reads a story, stzn renders both | real for the transcript; narration queued |
| **The trial is the deployment protocol** | nothing updates itself in place; the image is the unit; two slots; readiness ties the commit to "serving"; the machine judges its own boot and rolls back by hardware | real in the emulator (AB-1, RDY-1, JDG-1); the board's countdown waits on OS-5 |
| **The emulator is everyone's court** | any layer's integration test can boot the whole box in QEMU and be judged by a pinned transcript, before a board exists | real: three machines, one script |
| **One grammar family, one court** | the machine language is one declared language among the estate's; a world's needs are judged against the machine's grants at declaration time (R20 refuses a service that needs what nothing grants); the placement contract and an agent's declaration can be judged the same way | real for NEEDS; queued for placement and agents |

## 3. The application server: RingServ and stzAppServer

**What it is today.** RingServ is a static binary built by Zig that
serves HTTP by web standards, runs services declared in Ring, stores
in embedded SQLite, and syncs with local-first pages through a shape
log with per-client exactly-once pushes (`ringserv/docs/topology.md`,
`STREAM.md`). Its `reload` swaps code between two requests without
rebinding the port, is loopback-only by refusal, and "does not migrate
your data" (`DEPLOY.md`). Its Commons designs describe "a journaled,
partition-tolerant server" with a hash-chained, never-trimmable journal
for the French anti-fraud case, a two-plane bridge between the Makeen
box and the cloud, and a host abstraction "sized for a 200-euro
Android box" (`COMMONS.md`). stzAppServer is the same role inside
stzlib: HTTP/1.1, static files, REST over SQLite, signed requests on
every route, mounted auth and an OIDC provider
(`SOFTANZA_AUTH_PLAN.md`, `SOFTANZA_EMULATION.md`). TLS is ruled for
the whole estate: no repository vendors a TLS stack, and TLS terminates
at a proxy in front (`ringserv/docs/TLS.md`).

**What it borrows today.** A port and a firewall it does not control.
An address it discovers, which is exactly how two hours of a
restaurant owner's notes were lost when a lease changed. A supervisor:
a terminal window, a laptop lid, or a service manager configured by
hand. A filesystem path whose durability it cannot state. A clock it
did not declare. Logs that go somewhere. An identity for signing
requests, generated somewhere. An update path that stops at code and
leaves the data migration to the operator.

**What the floor gives it.**

- *The address is declared.* `NETWORK lan` with a static address and
  no gateway, brought up by PID 1 before the server starts, in the
  transcript. The origin never moves, so the pages' storage never
  becomes unreachable, and the box can hand out the names the notes
  asked for (`imprimante.makeen`) once the box-as-DHCP-server seam is
  built.
- *The port is the only surface.* No shell, no login, no second
  program on the boot path. The attack surface of the box is the
  declared service's port and nothing else, and the transcript says
  what is listening because nothing undeclared can.
- *PID 1 is the supervisor.* RESTART is a declared policy; READY is
  the server's own word that it is serving, which for RingServ is the
  moment the shape log answers; AFTER orders the server before the
  pages' worlds; and a trial of a new image never commits before that
  word. The laptop lid is not a failure domain any more.
- *The journal has a floor.* `MOUNT data` on the card's second
  partition, mounted before any world speaks, with declared options.
  The hash-chained journal RingServ designed for the fiscal case gets
  a partition whose durability is a declaration, and the
  signed-journal seat, when built, gives it a trusted clock and a
  sealed chain the auditor reads from the floor.
- *Identity from the floor.* The server runs as its own USER; the
  request-signing key and the box's key are one fact when the
  per-device identity lands; no key generated "somewhere".
- *The update is a trial.* RingServ's own refusal, "deploying from
  another machine is a different product with a different threat
  model", is answered without a new product: the new image reaches
  the other slot through refine's gate, the box tries it once, the
  server signals READY, the machine judges its boot, and only then the
  commit. Code, schema, runtime and OS move as one artifact; the data
  partition stays, which is why a migration must be forward-compatible
  and why the journal is versioned, not rewritten.
- *The host abstraction becomes a machine.* The "200-euro Android box"
  RingServ sized its Commons for is `machines/makeen_box.machine`; the
  two planes of its bridge are two machine files, the box's and the
  cloud's, and the roles the bridge insists be "declared, not inferred"
  are declared in the same grammar as the box.

**What it owes.** A server pack is a SERVICE line plus its needs: the
port, the mounts, the capabilities, the readiness path, the identity.
The server reads its envelope from `/etc/machine` rather than from a
configuration file, stays static, and writes to the transcript in the
shared prefix grammar. TLS stays where the estate ruled it, in front,
and the machine gives that front a declared place and an identity,
nothing more.

**Status.** By design: the server projection under stzp is ruled
(03-PRODUCTS), the box's stand-in worlds exit instead of serving, and
no server has yet been declared as a machine service. The first such
declaration is the Commons world of RestoLean, and it is the next
thing the box needs.

## 4. The runtime: stzr today, Ring++ and Haro tomorrow

**What it is today.** stzr is stz's static musl binary, the only other
program on the boot path, running the worlds under PID 1 in all three
machines. Ring++ is the register VM and the compiler in Zig, "sovereign,
not new", judged against Ring 1.27's VM as the oracle, on the road to
Haro; its charter's P8 says one binary, every target, no C toolchain
required of anyone, and its target table is honest: desktop and server
measured, Linux-class boards "plausible, unmeasured" pending an arm64
runtime and a bytecode-portability test, bare metal refused by name
(`ringpp/docs/DESIGN_BUILD.md` §3).

**What it borrows today.** A dynamic loader and a libc it did not
choose. A process model it did not declare. A memory ceiling it
discovers by being killed. An environment (variables, paths, locale)
that arrives from a shell. A notion of "which machine am I on" that
lives in a configuration file.

**What the floor gives it.**

- *The machine's architectures are the runtime's targets.* An image is
  built per ARCH by the same pipeline that builds the kernel, so the
  bytecode-portability question of the charter is answered by
  construction: the bytecode is built for the image it rides in. The
  "plausible, unmeasured" row for Linux-class boards becomes a
  measured row the day Haro's runtime replaces stzr in
  `zig-out/cross/aarch64-linux-musl` and boots the same three machines.
- *The envelope is the VM's policy.* The runtime reads `/etc/machine`
  and refuses what the machine did not grant: no filesystem outside the
  declared mounts, no network unless granted, no dynamic loading
  because `dynamic_load` is a capability the box refuses. The
  down-constrain law that stzlib wrote for the twin becomes the VM's
  reading of a file that is also the kernel's.
- *No third program.* Ring++ already refuses to package programs that
  reach Qt because it cannot see what the library reaches; the machine
  says the same thing from below: there is nothing on the path to
  reach. A static, libc-free runtime is not a nicety here, it is what
  makes "one binary, every role" true for the runtime as it is for
  PID 1.
- *Determinism.* A boot is a transcript; a world whose inputs are
  journaled can be replayed in the emulator. The fixture-guarded
  narrated suites that stzlib uses as its migration instrument get a
  floor where the run itself is a fixture.
- *Budgets.* When the resource seat lands, a world runs under a
  declared memory and CPU ceiling, and the collector can assume it
  instead of discovering it.
- *The compiler as the kernel's builder.* The sovereignty destination
  is that every line on the boot path is compiled by our toolchain.
  Today gcc builds the kernel; `zig cc` was tried and the image did not
  boot (ZIGCC-1), and the instrument is kept for the day Haro's own
  toolchain, or a newer zig, gets there. The floor is where that
  attempt is measured, not argued.

**What it owes.** Stay static and libc-free on Linux; read the
envelope from the machine file, never from the environment; keep bare
metal refused (the edge is MicroRing's); ship as the second binary of
the image, built by the same cross flag.

**Status.** Real for stzr. For Ring++ and Haro, by design: the seam is
one path in `experiment/os2_image.sh` (`zig-out/stz-<triple>/bin/stzr`)
and one SERVICE word, and the target table's Linux-class row is the
measurement to take.

## 5. Programmatic Intelligence, the intelligence and natural modules

**What it is today.** Softanza's intelligence architecture is bracketed
by knowledge on both ends: a knowledge graph with ontology and rules,
a planner, an optimizer, a classic-ML roster, and the "PI decision
stack" (perceive, decide, react, learn) that improves "without any
LLM", the revoked-LLM thesis
(`SOFTANZA_INTELLIGENCE_ARCHITECTURE.md`). The neural door binds raw
ggml in the engine, "so the machine is ours, and so is every bound in
it", and the structured-output contract C9 makes a grammar-violating
token unemittable at the sampler. The natural door is the near-natural
language paradigm, chain-of-truth, question frames, and the
conversational door lets a business owner talk knowledge in. The
twin, "Agents That Cannot Hurt You", is the safety story: the agent
lives inside a virtual system and the only artifact that leaves is an
update plan.

**What it borrows today.** Memory it cannot count on for a model. A
network it cannot prove it is not using, which is the whole of an
NGO's requirement that child-protection data never leave the perimeter.
A clock for its plans. No wall between the inference process and the
business world beside it. A machine it perceives through logs written
for people, in prose.

**What the floor gives it.**

- *Inference is a fact of the floor.* `CAPABILITY inference` is one of
  the nine names, granted or refused per machine, judged before boot.
  With egress by declaration (the seam DIKO's requirement names), an
  air-gapped intelligent box is a declaration the court can convict,
  not a promise in a proposal.
- *The model rides in the image, pinned.* Like the kernel: a digest,
  a file in the initramfs or on the data partition, no download, no
  update outside a trial. The intelligence a box has is exactly the
  intelligence it was declared with, and the auditor can read which.
- *A wall between worlds.* The inference world runs as its own USER
  under its own budget, so a model never starves the kitchen display.
  The budget seat is queued; the identity is real.
- *The agent's mouth is constrained on the box, including about the
  box.* The sampler that can only emit valid sentences of a declared
  language can emit sentences of the machine language. An agent on the
  machine can therefore propose a change to the machine: the draft is
  a `.machine` file, the court judges it, a person ratifies it, the
  image is derived, the box tries it once and judges its own boot. The
  twin's "only an update plan leaves" reaches hardware with every step
  judged, which is the complete governed loop the era thesis
  describes.
- *The transcript is the agent's perception.* The PI stack's first
  step, perceive, reads the floor as facts in a closed grammar: mount
  done, network up, service ready, judge matches. Those are
  knowledge-graph facts, not log lines to parse. The natural door can
  answer "why did the box not commit?" from the judge's own lines,
  because they are sentences with a grammar, and the conversational
  door can take a machine change in the same way it takes a fact.
- *Rehearse on the twin, commit through the trial.* stzlib's virtual
  system rehearses an agent's file, database and network effects; the
  machine judges the real act after. The two share the capability
  vocabulary verbatim, and the twin should read `/etc/machine` as its
  profile so the rehearsal and the act have one declaration.

**What it owes.** Declare the model as an asset with a digest, declare
inference and its egress, declare its budget when the seat exists, and
speak to the machine in the transcript's grammar.

**Honest boundary.** A Raspberry Pi 4 is a weak inference host: no
accelerator, four to eight gigabytes. The classic PI stack fits it
well; small language models run on it slowly. The newest phones carry
the accelerators, which is B9's own point that "no home-made box will
ever have local AI like theirs". So the placement decision is C3's,
not the floor's: the box carries the rules and the journal, the touch
device carries the model, and both are declared.

## 6. The pages: RingScript and the remote control

**What it is today.** The Ring VM compiled to WebAssembly and resident
in the page, local-first, a two-way bridge to JavaScript, the remote
control of the RestoLean pivot (`ringscript/README.md`,
`CONSTELLATION.md`).

**What the floor gives it.** A stable origin, which is the single
largest dividend of the whole document because it was paid for in the
field: the storage a browser partitions by origin stays reachable when
the box's address is declared rather than leased. A page served by a
box whose name is a declaration. A Commons that is a declared service
with a readiness signal. Offline-first pages that reconnect to an
address that did not move.

**Status.** By design; the touch profile that would put the box's
posture on the phone itself is a design only.

## 7. The devices: MicroRing and the sensors

**What it is today.** The edge substrate: MicroZig, littlefs, the
cooperative loop as scheduler, `Device([...])`, a per-device Ed25519
identity that never leaves the board (`microring/docs/identity.md`).
The sensor is projected from a `.machine` file and judged by MicroRing
itself (PRJ-1, PRJ-2).

**What the floor gives it.** A gateway that is a declared machine: the
box is the sensors' first hop, its journal the sensors' durable log,
its slots the sensors' firmware update path through the same gate, its
identity the verifier of theirs. The HACCP evidence chain runs from a
thermistor to a signed journal without leaving declared ground.

**Status.** The projection is real; the gateway role is a projection.

## 8. zin: the constitution gets a floor

**What it is today.** The constitutional compiler and platform: six
articles, fifty-six pillars, ZinFoundry packs, agent fleets. Pillar 19,
Zos, "declares platform-level capabilities: filesystem, network, OS
services, hardware" with `DEFINE CAPABILITY`, `REQUIRE`, `PLATFORM`,
`FEATURE`, and is planned, not built (`PILLAR_REFERENCE_v10_2.md`).

**What the floor gives it.** A substrate for Zos: a `REQUIRE` in a Zos
declaration is judged against a machine's grants, one language per
altitude as ruled in `PROVENANCE.md`. Article 3, visible state, at the
floor: the transcript. Article 2, reversibility: two slots and a
watchdog. Article 5, agentic sovereignty: the agent's sandbox is the
machine's envelope, enforced below the runtime. Telemetry (Zov) read
from transcripts rather than probes; rollout as images through the
gate; the ZinFoundry pack as the machine's SERVICE list; "the device
is the job" as an image rather than a launcher; and the fleet
constitution over a set of machine files, the fleet court that
`GROUND.md` §6 names.

**Status.** Queued: Zos is planned; the fleet court is not built.

## 9. refine: the change reaches the floor

**What it is today.** The refinement as the unit of change, the cascade
as validation, the gate as the canonical writer, the audit chain as
provenance, live refinement against a running project
(`refine/README.md`).

**What the floor gives it.** A new refinement kind whose artifact is a
machine diff and an image digest; a cascade whose last step is a boot
in the emulator; a gate whose rollback is hardware; an audit chain that
ends at the machine's own verdict on its boot; and live refinement
against a running box, where the live monitor is the transcript. The
corpus already states the law: a migration is a governed refinement,
never a shell script. The floor is what makes the shell script
impossible rather than forbidden.

**Status.** By design; no gate is wired to `stzos update`.

## 10. The projections and the Studio: Zing, stzp, Softanza Studio

**What the floor gives them.** One more declared world to show, and a
new projection target: the machine's console, and, when a hosted
machine gains a display seat, the kiosk. The Studio's device lens
shows machine files, plans, transcripts and verdicts as pages, and a
fleet as a map of machine files. One truth, files; the machine is a
file too.

**Status.** By design; the display seat for hosted machines is a named
seam, and the device lens is commercial and stays out of this
repository.

## 11. The narrator and the practice: stzn, Bangalo, the twin

- **stzn** renders the plan, the transcript and the verdict as
  narrations; the evidence page an auditor reads is its first job at
  the floor. Queued.
- **Bangalo** is how the floor was built: one session, one human,
  fixtures first, the mechanism asserted with a mutated judge, each
  trap paid for and written down. Its dividend to the next session is
  `CLAUDE.md`'s trap list, and its dividend to the estate is that the
  emulator court makes floor work parallel across sessions without a
  board. Real.
- **stzlib's System Foundation**, the twin, shares the machine's
  vocabulary verbatim and should share its declaration: the twin reads
  the machine file as its profile, so "rehearse, plan, commit" is one
  loop from the agent's sandbox to PID 1. Queued: today the two
  languages are the same nine words in two files.

## 12. What the layers owe the floor, in one list

Every dividend above is collected by the same act. A layer declares
its needs in its own closed grammar: its port, its mounts, its
capabilities, its identity, its readiness path, its budget, its model
as a pinned asset. It stays static and shell-free. It reads its
envelope from `/etc/machine`, not from the environment. It writes to
the transcript in the shared prefix grammar. It treats the image as
its deployment unit and the trial as its deployment protocol. Nothing
here asks a layer to change what it is; it asks each to say what it
needs, which is the act the whole estate is built on.

## 13. The seams the dividends need, unordered

Each is named here so the author can order them; none is built.

1. Egress by declaration: whom a machine may speak to, with the
   firewall derived (DIKO's requirement, §5's air gap).
2. Budgets: a memory and CPU ceiling per service (§4, §5).
3. The envelope at the kernel: namespaces and allowed system calls
   derived from CAPABILITY (§2).
4. The signed journal and a trusted clock (§3, §7).
5. The per-device identity, an Ed25519 key that never leaves the
   board, verified by the box (§3, §7).
6. The box as the network's server of addresses and names (§3, §6).
7. The model as a pinned asset of the image (§5).
8. NEEDS judged against a world's own manifest and the placement
   contract, so a topology that places a service on the box is judged
   against the box (§2, §3).
9. The twin reading the machine file as its profile (§11).
10. A display seat for hosted machines, for the kiosk (§10).
11. The fleet court: a set of machine files judged together (§8).
12. Haro's runtime as the image's second binary, and the Linux-class
    row of Ring++'s target table measured on the three machines (§4).

## 14. Honest boundaries

- The dividends the three machines already pay are the declared
  address, the mounts before worlds, the identities, the readiness
  signal, the trial, and the machine's own verdict. Everything else in
  this document is a seam, marked as such.
- No application server has been declared as a machine service; the
  box's worlds are stand-ins that exit.
- Haro does not exist yet, and Ring++'s Linux-class row is unmeasured.
- The Pi 4 is a weak inference host; the placement of models is C3's
  decision.
- TLS is ruled for the estate and not by this repository.
- The touch profile is a design; the display seat does not exist;
  the board is on order.
