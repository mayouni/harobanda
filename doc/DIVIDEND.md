# The Dividend — what owning the floor gives every layer above it

*2026-09-13, rewritten the same day for the north-star reflection
(`softanza/vision/08-NORTH-STAR.md`). The author's question: what does
an application server like RingServ or stzAppServer gain when we own
not only the server but the operating system under it? The same
question for Ring++ and the future Haro, for Programmatic Intelligence
and the intelligence and natural modules, for every tool. This
document answers in plain terms, with one example per layer. Every
"today" is checked in the repositories; every "tomorrow" is marked.
Companion of `GROUND.md`. Unratified.*

## 1. The idea in one scene

**Scene one, real.** On 15 August 2026, at CousBox in Lyon, a laptop
was the server, a phone the customer's remote control, a tablet the
kitchen display, all on the restaurant's Wi-Fi. A faulty refrigerator
tripped the breaker. The internet box rebooted and gave the laptop a
new address. The browser keeps its data under the page's address, so
two hours of the owner's notes became unreachable
(`softanza/prompts/22-partition-tolerance-placement.md`).

Nothing in that story is a bug in the server. The server did what it
was told. The floor under it moved.

**Scene two, the same server on a declared machine.** The box behind
the counter is one text file, `machines/makeen_box.machine`. Three of
its lines:

```
  CONSOLE "/dev/ttyS1",
  SLOTS "/dev/mmcblk0p1"
...
DEFINE NETWORK lan AS (
  INTERFACE "eth0",
  ADDRESS "192.168.10.1/24"
) RATIONALE "The box is the network's address; the phones find it here. No gateway: the box is the gateway"
...
DEFINE MOUNT data AS (
  AT "/data", FS ext4, DEVICE "/dev/mmcblk0p2", OPTIONS [rw, noatime]
) RATIONALE "The persistent partition: the SD card's second partition"
```

And what the box says as it boots, before any server starts:

```
boot: mount ext4 at /data -- done
boot: network lan -- eth0 up 192.168.10.1/24
boot: watchdog armed (/dev/watchdog)
boot: start kds -- pid N -- /stzr /app/kds.luau
boot: judge -- the boot matches its expectation (/etc/expected, 16 lines)
```

The address is not leased. It is declared, brought up by PID 1, and in
the transcript. The refrigerator can trip the breaker; the box restarts
into the slot it committed, the journal is on its partition, and the
page finds the same address it found yesterday.

**That is the dividend, in one sentence: every hope a layer carries
about its environment becomes a line the machine declares, judges
before boot, and proves in its transcript; the code that hoped can be
deleted.**

## 2. How to read this document

Every layer of the estate was written on a floor it did not own, and
each carries the marks: an address it discovers, a port it hopes is
free, a supervisor it hopes for, a memory ceiling it learns by being
killed, a model it hopes fits, a log nobody reads. Each of those is
code. For each layer below, the document lists the hopes, the lines
that replace them, one example, and the layer's one obligation, which
is always the same: *declare what you need, in your own closed
grammar, so the floor can grant it and judge it.*

## 3. The rule of the game: declare what you need

A service on a declared machine is one declaration:

```
DEFINE SERVICE commons AS (
  RUN ["/stzr", "/app/commons.luau"],
  RESTART always,
  READY "/run/commons.ready",
  USER world,
  NEEDS [network, filesystem]
) RATIONALE "The Commons: catalogue, orders, payments; it says when it is serving"
```

Each word is something the floor does for the service:

| the word | what the floor does with it |
|---|---|
| `RUN` | starts exactly this program with exactly these words, never through a shell |
| `RESTART always` | PID 1 restarts it when it dies, and says so in the transcript |
| `READY` | the service's own word that it is serving; nothing that comes AFTER it starts before, and an update trial never commits without it |
| `USER world` | the service runs as this identity, never as the machine; uid 0 cannot be declared |
| `NEEDS [network, filesystem]` | the court refuses the whole machine if any of these is not granted: `needs gpio, which no declaration grants` |

That is the entire contract between a layer and the floor. Everything
in the rest of this document is a consequence of it.

## 4. Eight things every layer gets

| what you get | what it means, plainly | today |
|---|---|---|
| **a floor that is a fact** | every mount, address, identity and start order is declared and in the transcript before your first line runs | real: three machines boot in emulators, pinned transcripts |
| **an envelope below you** | what the machine refuses, you cannot do; the runtime refuses it today, the kernel will (namespaces, allowed system calls, budgets) | real at the runtime; the kernel half queued |
| **an identity from the floor** | you run as a declared USER; a per-device key that never leaves the board comes next | real; the key queued |
| **a durable place and a clock** | a partition mounted before you speak, with declared options; the clock a capability; a signed journal a named seat | real for the mount; the journal seat named |
| **one narrative** | your output is a line in the machine's story, with a prefix and a grammar; no syslog, no journald | real |
| **updates as trials** | you never update yourself in place; the image is the unit, two slots, the machine judges its own boot and rolls back by hardware | real in the emulator; the board's countdown waits for OS-5 |
| **an emulator as your test bench** | your integration test boots the whole box in QEMU and is judged by a pinned transcript | real: one script |
| **one court** | your needs are judged against the machine's grants at declaration time; tomorrow, the placement of your services and an agent's declaration too | real for NEEDS; the rest queued |

## 5. The application server: RingServ and stzAppServer

**Today.** RingServ is one static binary serving HTTP, running services
declared in Ring, storing in SQLite, syncing local-first pages through
a shape log (`ringserv/docs/topology.md`). Its `reload` swaps code
without restarting, works only from the machine itself by refusal, and
"does not migrate your data" (`DEPLOY.md`). Its Commons designs
describe a hash-chained journal for the French cash-register law and a
host "sized for a 200-euro Android box" (`COMMONS.md`). stzAppServer is
the same role inside stzlib, with signed requests on every route and a
mounted OIDC provider (`SOFTANZA_AUTH_PLAN.md`). TLS is ruled for the
estate: it terminates at a proxy in front, and no repository vendors a
TLS stack (`TLS.md`).

**What it hopes for today.** A free port. An address that stays. A
supervisor (a terminal, a laptop lid, a service manager configured by
hand). A disk whose durability it cannot state. A clock. A place for
logs. A key generated somewhere. An update path that stops at the
data.

**What the floor gives.**

- The address is declared. The page's origin never moves.
- The port is the only surface: no shell, no login, no other program
  on the boot path, so what listens is what was declared.
- PID 1 is the supervisor. `READY` is the server's own word, and for
  RingServ that is the moment the shape log answers.
- The journal has a partition mounted before the server starts.
- Identity from the floor: the server's USER, and later the box's
  key, so the request-signing key is not "generated somewhere".
- The update is a trial. RingServ refuses to deploy from another
  machine because that is "a different product with a different
  threat model". The floor answers without a new product: the new
  image reaches the other slot, the box tries it once, the server
  says READY, the machine judges its boot, and only then the commit.
- The "200-euro box" RingServ sized its Commons for is
  `machines/makeen_box.machine`.

*Example.* The one line that would have saved the two hours on
15 August is the NETWORK line in §1. Everything else on the box is
consequence.

**What it owes.** A server pack is a SERVICE line plus its needs: port,
mounts, capabilities, readiness path, identity. It reads its envelope
from `/etc/machine`, not from a configuration file. TLS stays in front,
where the estate ruled it; the machine gives that front a declared
place and nothing more.

**Status.** By design. No server is yet declared as a machine service.
The box's worlds became daemons with READY paths on 2026-09-13 (SRV-1),
so the shape a server needs is proven — start, serve, signal, be waited
for, halt only on the court's instrument. RestoLean's Commons world is
the first candidate.

## 6. The runtime: stzr today, Ring++ and Haro tomorrow

**Today.** stzr is stz's static binary, the only other program on the
boot path, running every world in the three machines. Ring++ is the
register VM and compiler in Zig on the road to Haro; its charter says
one binary for every target and no C toolchain for anyone (P8), and
its target table is honest: desktop and server measured, Linux-class
boards "plausible, unmeasured", bare metal refused
(`ringpp/docs/DESIGN_BUILD.md` §3).

**What it hopes for today.** A dynamic loader and a libc it did not
choose. A memory ceiling it discovers by being killed. An environment
that arrives from a shell. A configuration file that says which
machine this is.

**What the floor gives.**

- The machine's architectures are the runtime's targets, built by the
  same cross flag as PID 1, so bytecode is built for the image it
  rides in. The "plausible, unmeasured" row becomes measured the day
  Haro's runtime replaces stzr in the image and boots the same three
  machines.
- The envelope is the VM's policy. The runtime reads `/etc/machine`
  and refuses what the machine did not grant.
- No third program. Ring++ already refuses to package a program that
  reaches a library it cannot see through; the machine says the same
  from below: there is nothing on the path to reach.
- Determinism: a boot is a transcript; a world with journaled inputs
  replays in the emulator.
- Budgets, when the seat lands: a declared ceiling the collector can
  assume.
- The compiler as the kernel's builder, one day: today gcc builds the
  kernel, `zig cc` was tried and the image did not boot (ZIGCC-1), and
  the instrument is kept.

*Example.* A world asks for a file outside its declared mounts. The
answer belongs to the runtime today, by the down-constrain law, in
this shape (the wording is illustrative: stzr does not yet read the
machine file):

```
stzr: /etc/shadow refused -- the machine grants filesystem at /data only
```

Tomorrow the kernel gives the same answer before the runtime sees the
call, from the same line of the same file.

**What it owes.** Stay static and libc-free; read the envelope from the
machine file; keep bare metal refused; ship as the image's second
binary.

**Status.** Real for stzr. For Haro, by design: one path in
`experiment/os2_image.sh` and one SERVICE word.

## 7. Programmatic Intelligence, the intelligence and natural modules

**Today.** The intelligence architecture is bracketed by knowledge on
both ends: a knowledge graph with ontology and rules, a planner, an
optimiser, a classic-ML roster, and the PI decision stack (perceive,
decide, react, learn) that improves "without any LLM"
(`SOFTANZA_INTELLIGENCE_ARCHITECTURE.md`). The neural door binds raw
ggml in the engine, "so the machine is ours, and so is every bound in
it"; contract C9 constrains a model's sampler to a declared grammar,
so a malformed sentence cannot be emitted. The natural door is the
near-natural paradigm and the question frames; the conversational door
lets a business owner talk knowledge in. The twin, "Agents That Cannot
Hurt You", lets an agent do anything inside a virtual system, and the
only artifact that leaves is an update plan.

**What it hopes for today.** Memory for a model. A network it cannot
prove it is not using, which is the whole of an NGO's requirement that
child-protection data never leave the perimeter (`diko/`). A wall
between the inference process and the business world beside it. A
machine it perceives through logs written for people.

**What the floor gives.**

- Inference is a fact of the floor: `CAPABILITY inference` is one of
  the nine names, granted or refused per machine, judged before boot.
  With egress declared (a seam), an air-gapped intelligent box is a
  declaration the court can convict, not a promise in a proposal.
- The model rides in the image, pinned by digest like the kernel. The
  intelligence a box has is exactly the intelligence it was declared
  with, and an auditor can read which.
- A wall between worlds: the inference world runs as its own USER
  under its own budget, so a model never starves the kitchen display.
- The agent's mouth is constrained on the box, and it can speak about
  the box. Because the machine language is a declared grammar, an
  agent on the machine can propose a change to the machine:

```
  the agent drafts     DEFINE SERVICE alerts AS (RUN ["/stzr", "/app/alerts.luau"], RESTART always, NEEDS [network]) RATIONALE "..."
  the court judges     machine (line 41): alerts needs network, which no declaration grants
  the agent revises    DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "..."
  a person ratifies    the new .machine file
  the image is derived stzos image; /etc/expected gains two lines
  the box tries it     boot: slot B -- a trial (committed is A)
  the box judges       boot: judge -- the boot matches its expectation (/etc/expected, 18 lines)
  the box commits      boot: slot B -- committed: every service is ready and the boot matches its expectation
```

  Every step in that list exists today except the first two being
  done by an agent, and those are C9 pointed at one more grammar.

- The transcript is the agent's perception. The PI stack's first step,
  perceive, reads the floor as facts in a closed grammar: mount done,
  network up, service ready, judge matches. Those are knowledge-graph
  facts, not log lines to parse. Asked "why did the box not commit?",
  the natural door can answer from the judge's own lines:

```
boot: judge -- expected, not said: network lan -- eth0 up 192.168.10.1/24
```

- Rehearse on the twin, commit through the trial. The virtual system
  rehearses the agent's effects; the machine judges the real act. Both
  speak the same nine capability words, and the twin should read
  `/etc/machine` as its profile so there is one declaration.

**What it owes.** Declare the model as a pinned asset, declare
inference and its egress, declare a budget when the seat exists, and
write to the transcript in its grammar.

**Honest boundary.** A Raspberry Pi 4 is a weak inference host: no
accelerator, four to eight gigabytes. The classic PI stack fits it;
small language models run on it slowly. The newest phones carry the
accelerators, which is B9's own point. So the placement is C3's: the
box carries the rules and the journal, the touch device carries the
model, and both are declared.

## 8. The pages: RingScript and the remote control

**Today.** The Ring VM in WebAssembly, resident in the page,
local-first, the customer's remote control at RestoLean.

**What the floor gives.** A stable origin, the single largest dividend
in this document because it was paid for in the field. A page served
by a box whose name is a declaration. A Commons that is a declared
service with a readiness signal.

*Example.* A QR code on a table encodes the box's declared address. It
is printed once. It never changes because a refrigerator tripped a
breaker.

**Status.** By design; the touch profile that would put the box's
posture on the phone itself is a design only.

## 9. The devices: MicroRing and the sensors

**Today.** The edge substrate: the tiers, littlefs, the cooperative
loop as scheduler, `Device([...])`, a per-device Ed25519 identity that
never leaves the board (`microring/docs/identity.md`). A sensor is
projected from a `.machine` file and judged by MicroRing itself
(PRJ-1, PRJ-2).

**What the floor gives.** A gateway that is a declared machine: the
box is the sensors' first hop, its journal their durable log, its slots
their firmware update path, its identity the verifier of theirs.

*Example.* The refrigerator that tripped the breaker is the ground's
own request for a sensor:

```
Device([
    :board = "pico2",
    :pins = [
        :led = [ :gpio = 25, :mode = :out ],
        :probe = [ :gpio = 4, :mode = :in ]
    ]
])
```

That file was written by `stzos project` from
`machines/cold_room_sensor.machine`, and MicroRing ran it unchanged.
The HACCP evidence a restaurant needs would run from that probe to
the box's journal without leaving declared ground.

**Status.** The projection is real; the gateway role is a projection.

## 10. zin: the constitution gets a floor

**Today.** Six articles, fifty-six pillars, ZinFoundry packs, agent
fleets. Pillar 19, Zos, "declares platform-level capabilities:
filesystem, network, OS services, hardware", and is planned, not
built.

**What the floor gives.** A substrate for Zos: a `REQUIRE` in a Zos
declaration is judged against a machine's grants, one language per
altitude. Article 3, visible state, becomes the transcript. Article 2,
reversibility, becomes two slots and a watchdog. Article 5, agentic
sovereignty, becomes the machine's envelope, enforced below the
runtime. Telemetry read from transcripts; rollout as images; the
foundry pack as the machine's SERVICE list; a fleet constitution over
a set of machine files.

*Example.* `REQUIRE network` in a Zos declaration for the kitchen
display, judged against `makeen_box.machine`, which grants network and
refuses gpio: accepted for network, refused if it ever asked for a pin.

**Status.** Queued: Zos is planned; the fleet court is not built.

## 11. refine: the change reaches the floor

**Today.** The refinement as the unit of change, the cascade as
validation, the gate as the canonical writer, the audit chain as
provenance.

**What the floor gives.** A refinement kind whose artifact is a
machine diff and an image digest; a cascade whose last step is a boot
in the emulator; a gate whose rollback is hardware; an audit chain that
ends at the machine's own verdict on its boot.

*Example.* A refinement "grant the box the clock" is one added line in
a `.machine` file and one changed digest. Its cascade shows two new
lines in `/etc/expected`. Its rollback is the other slot.

**Status.** By design; no gate is wired to `stzos update`.

## 12. The projections, the narrator, the practice, the twin

- **Zing, stzp, the Studios**: one more declared world to show, and
  the machine's console as a projection target; a fleet as a map of
  machine files. By design; a display seat for hosted machines is a
  named seam.
- **stzn**: the plan, the transcript and the verdict rendered as
  narrations; the evidence page an auditor reads. Queued.
- **Bangalo**: how the floor was built, one session, one human,
  fixtures first; the emulator court is what lets many sessions share
  floor work without a board. Real.
- **the twin** (stzlib's System Foundation): the same nine words in
  two files today; the twin should read the machine file as its
  profile so "rehearse, plan, commit" is one loop from the agent's
  sandbox to PID 1. Queued.

## 13. Where the dividend lands in the north star

The reflection `softanza/vision/08-NORTH-STAR.md` redraws the 2020
diagram. This is where the floor pays each band of it:

| band of the diagram | what the floor gives it |
|---|---|
| who it is for | the programmer in a small team gets a machine that boots on a laptop and a board alike; the agent gets a floor it can propose changes to and cannot harm |
| solutions | CAPABILITY: the machine is open mechanism; PROJECTION: one file, three profiles; EXPERIENCE: the device that is the job, the fleet agents |
| systems | technical: a boot that judges itself; social: the merchant's numbers stay home; ecological: a 100-euro board and used phones; economic: no licence, no store; cultural: French, two gestures |
| languages | `.machine` is one more declared language, judged by the meta-court, with a mouth for agents |
| foundation | stzr is the image's second binary; the fixture discipline reaches PID 1 |
| beneath | this is the band; the floor is what the diagram's "metal force" pointed at |

## 14. The seams the dividends need, unordered

1. Egress by declaration: whom a machine may speak to, with the
   firewall derived.
2. Budgets: a memory and CPU ceiling per service.
3. The envelope at the kernel: namespaces and allowed system calls
   derived from CAPABILITY.
4. The signed journal and a trusted clock.
5. The per-device identity, verified by the box.
6. The box as the network's server of addresses and names.
7. The model as a pinned asset of the image.
8. NEEDS judged against a world's own manifest and the placement
   contract.
9. The twin reading the machine file as its profile.
10. A display seat for hosted machines.
11. The fleet court: a set of machine files judged together.
12. Haro's runtime as the image's second binary, and Ring++'s
    Linux-class row measured on the three machines.

## 15. Honest boundaries

- The dividends the three machines already pay: the declared address,
  the mounts before worlds, the identities, the readiness signal, the
  trial, the machine's own verdict. Everything else here is a seam.
- No application server is yet a machine service. The box's worlds
  serve and signal (SRV-1), but they stand in for the real ones.
- Haro does not exist; Ring++'s Linux-class row is unmeasured.
- The Pi 4 is a weak inference host; model placement is C3's.
- TLS is ruled for the estate, not here.
- The touch profile is a design; the display seat does not exist; the
  board is on order.
