# Real time — a timed machine, declared, judged and measured

*Written 2026-10-13 from the author's question: allow Harobanda to
support real-time systems, so that any RTOS-like solution -- autonomous
robots and systems among them -- can be built on top of it, deepening
the OS foundation and delegating the other layers to Haro (programming),
Softanza (application design) and Aïcha (intelligence). This is the
analysis, not a ruling: every clause named here is a proposal until the
author says the word, and nothing below is built. Read `GROUND.md` for
what the machine is for, `CLOUD.md` for the ladder this one stands
beside, and `PROVENANCE.md` for the refusals this direction touches.*

## 1. The question, split in two

"Real time" names two different promises, and the estate has already
drawn the line between them (`microring/docs/robotics.md` §3, read at
`048165f`):

- **Firm real time**, on the hosted profile: a world asks the kernel
  for time it will get every period, within a bound, and the bound is
  MEASURED on the board it runs on -- tens of microseconds on a PC with a
  good firmware, a few hundred on a Raspberry Pi 4, as others report;
  this floor prints its own number or says UNMEASURED. Never proven: no
  worst-case analysis of the Linux kernel exists, and nobody certifies
  one.
- **Hard real time**, at the edge: a loop whose every step has a bounded
  worst case, small enough to bound by reading it. That is a
  microcontroller running a cyclic executive, or silicon (the RP2350's
  PIO state machines, which hold a pulse train "regardless of what the
  VM is doing").

An "RTOS-like solution" on Harobanda is therefore not one machine. It is
**two tiers in one language**: a brain (hosted, a timed Linux kernel,
worlds with reservations) and a body (edge, a declared schedule on
MicroRing's substrate), joined by a declared wire and a heartbeat, and
judged as a SET -- which is the shape the fleet grammar already judges.
A robot is the smallest cloud with a body. The cloud ladder taught how to
compose machines (`CLOUD.md`); this ladder composes two kinds of time.

What the floor refuses, by its own doctrine, stays refused: there is no
RTOS here -- no thread API, no priorities an application sets, no second
kernel. "Not an RTOS" was kept on 2026-09-12 (`07-SYSTEM.md`,
`PROVENANCE.md` §"Three standing refusals") because *the loop is the
scheduler*. This analysis keeps it, and gives the loop a declared
schedule.

## 2. The floor today, measured before anything is proposed

Read in the code and probed in the kernel tree the floor vendors
(`linux-6.12.109`, `vendor/PIN.md`), on 2026-10-13:

| what | today | what it means for time |
|---|---|---|
| the preemption model | every kernel this floor has built (fifteen build directories under WSL) is `CONFIG_PREEMPT_NONE=y` | the least preemptible model Linux has: a server's kernel, where a world waiting to run waits for whatever the kernel is doing |
| the timers | `CONFIG_HZ=250`, no `HIGH_RES_TIMERS` | a sleep rounds up to 4 ms; a 1 ms loop cannot be written |
| the cores | x86 builds `NR_CPUS=1` and no `SMP`; arm64 `SMP=y` | the emulated PC has one core, so nothing can be isolated on it |
| `PREEMPT_RT` | in this tree, mainline: `depends on EXPERT && ARCH_SUPPORTS_RT`; x86, arm64 and riscv select `ARCH_SUPPORTS_RT`; `CONFIG_EXPERT=y` is already set | the real-time kernel is one derived option away, on both architectures the floor builds, with no out-of-tree patch (6.12 is the LTS where it arrived) |
| the deadline scheduler | `kernel/sched/deadline.c` is built unconditionally; `sched_setattr` runs an admission test (`__dl_overflow`) and answers `-EBUSY` to a set that does not fit; `SCHED_FLAG_DL_OVERRUN` signals a world that overran | the kernel already holds a RESERVATION the way it holds a ceiling (BDG-1), and refuses what it cannot keep -- a court inside the kernel |
| the read-back | no `/sys/kernel/realtime` in this tree; `init/Makefile` appends `PREEMPT_RT` to the version string | a boot can read its own model back from `uname` and say it (CON-1) |
| budgets | `cpu.max` throttles past a share (BDG-1); `memory.max` kills; `pids.max` refuses | ceilings, which are the opposite of a reservation: a ceiling says *no more than*; time needs *at least, and by then* |
| PID 1's own clock | it looks at its worlds every 250 ms and feeds the watchdog in that loop; `HEALTH` is whole seconds (1 to 3600) | the floor's finest promise about liveness is a quarter of a second; a control loop lives three orders of magnitude below it |
| a world's scheduling | `spawn` sets namespaces, the filter and the identity, and nothing about scheduling, affinity or limits | a world runs at the default policy on whatever core, and the floor never said otherwise |
| the deny list (SYS-1) | names the clock setters, not `sched_setscheduler`, `sched_setattr`, `setpriority` or `mlockall` | **a world that runs as the machine keeps `CAP_SYS_NICE` and may take a real-time priority nobody granted** -- on a one-core machine, down to the 5 % the kernel's throttle leaves PID 1. A USER world cannot (`RLIMIT_RTPRIO` is 0). Found by reading; no boot shows it; it is a seam whatever the author rules below |
| swap | none: `swapon` is refused to every world and no image has any | one real-time property the floor already has: nothing is paged out |
| the edge profile | declared here, projected to MicroRing (board and pins); the loop is MicroRing's, cooperative; behaviour is the Device language's and is not built | the body has no declared timing at all today |

So the honest starting line is: **the floor is a server today, and a
calm one.** Every real-time property is a derivation away, and none is
a kernel line away -- which is exactly the dividend the floor exists
for (`DIVIDEND.md` §4): a hope the layer above carries about its
environment becomes a line the machine declares, judges and proves.

## 3. What belongs to whom

The author's delegation is the right one, and the floor's doctrine says
where each line falls: *the budget asks how many and belongs to the
kernel; the capability asks who asked and belongs to the runtime*
(THR-1). Time is a budget.

| layer | what it owns in a timed system | what it cannot own |
|---|---|---|
| **Harobanda** (the floor) | the kernel's preemption model and timers, derived; a RESERVATION per world (period, deadline, runtime), set by PID 1 before the exec and held by the kernel's own admission; an isolated core per world that asks for one; the latency WITNESS and its number; the heartbeat between tiers and the wiring of a safe state; the edge tier's SCHEDULE, declared and projected; the robot as a fleet; the records | the control algorithm; a deterministic runtime; a certificate; any thread or priority API for an application |
| **Haro** (programming) | what a reservation is worth nothing without: execution whose worst case is bounded -- no collector pausing inside a deadline, an allocation-free subset for a control loop, `mlockall` as the runtime's own act (memory locks do not survive an exec, so the floor can only grant the limit); on the edge, the kHz "muscle" in compiled code | the reservation itself, the core, the kernel |
| **Softanza** (application design) | the robot as a declaration -- zin's **Zrb** pillar already names it: "Morphology / Kinematics / Actuation / Perception / Behavior, URDF export, constitutional safety" (`ROBOT maqeen_rover { ... }`, post-v1.0, `zin/doc/architecture/PILLAR_OVERVIEW.md` at `cc98126`) -- projected into machine files, packs and a fleet file with periods and deadlines; the modes, the safety invariants, what a SAFE STATE IS for this robot; the mission rehearsed in the twin (rehearse, plan, commit) and in MicroRing's scenario physics | the floor's mechanisms; the runtime's determinism |
| **Aïcha** (intelligence) | perception and planning as confined worlds with ceilings (BDG-1), whose outputs are PROPOSALS into a deterministic layer; an agent whose effect-capability set is empty (the System Foundation's law); kept out of the deadline path by construction: a world with a reservation takes nothing from an inference world but a declared channel | anything in the control loop; the actuator; the safe state |

The split is already the estate's. `robotics.md` says it for Ring: *Ring
holds the judgment at tens of Hz; the substrate holds the muscle --
PWM, encoder edges, PID inner loops at kHz -- in hardware or Zig.* The
floor is the substrate's declaration. What this direction adds is that
the muscle's timing becomes a declared, judged, measured fact rather
than an engineer's good manners.

## 4. The ladder

Six rungs, in the order the dependencies allow. Each names the clause it
proposes (every name provisional, the author's to rule), the judge, what
it buys, and its status: **rungs 1 and 2 are built** (TIM-1, 2026-10-13,
with the corrections §7 records beside what this section proposed), the
other four are not.

**Rung 1 -- the timed kernel.** A machine that carries any world with a
reservation is built `PREEMPT_RT`, with high-resolution timers, CPU
isolation and cpusets, derived into `kernel.fragment` the way `MEMORY`
derives the cgroup controllers today (`src/image.zig`); the cores a
machine has are declared for the emulator (`-smp` derived) and known for
a board (the Pi 4 has four). The boot reads its own model back from the
version string and says it, once, in the ledger: a timed machine that
booted a calm kernel differs from its expectation (NS-1, CON-1).
*Judge:* a pinned boot in the emulator (the mechanism: the derivation and
the read-back); the build prints every requested option that did not
survive, as it does today. *Buys:* the kernel the rest stands on.
*Cost, named:* a longer build, a throughput cost on every world of that
machine, and one more kernel configuration per machine to cache.

**Rung 2 -- the reservation.** On a SERVICE:

```
  PERIOD 1000,      -- microseconds: the loop's period
  DEADLINE 500,     -- by when, in each period
  RUNTIME 200,      -- the time the kernel reserves per period
  CORE 3,           -- an isolated core, this world's alone
```

PID 1 sets `SCHED_DEADLINE` in the child, after the gate and before the
exec (the attributes survive the exec; the identity drop comes after, as
today); the world's group is a cpuset partition of its one core. The
court judges the arithmetic before any boot -- runtime no more than
deadline no more than period, the reservations on one core summing to
no more than the kernel will take, a reserved world that NEEDS no
`process` (a deadline task may not fork) -- and the kernel judges it
again at the act: a set it cannot keep is refused with `EBUSY`, and PID
1 does not start that world and says so, as it does for an envelope it
cannot build. Two judges of one rule is EGR-3's trap, so the court's
arithmetic is a PRE-check that explains, and the kernel's answer is the
act; the ledger carries the kernel's. A reserved world that overruns is
signalled by the kernel (`SCHED_FLAG_DL_OVERRUN`), and what it does
then is the world's (rung 4). `cpu.max` and a reservation are refused
together on one world: a ceiling and a floor on the same time is a
contradiction the court can read.
*Judge:* `machines/qemu_deadline.machine` -- two reserved worlds inside
the core's time and a third that asks for more than there is, refused by
the kernel, the boot saying so; the court's cases for every rule above,
each probed by a mutant; a world as a USER with a reservation, to show
that the floor gives what a world could never take. The emulator can
judge all of this, because admission is arithmetic. *Buys:* the first
promise about time the floor can make and keep: *this world gets 200 µs
of every millisecond, and nothing else on the box can take it.*
*Refused, unless ruled otherwise:* `SCHED_FIFO` by a declared priority.
A priority is a claim nobody checks -- the kernel accepts any set of
them and starves the rest -- where a reservation is refused when it does
not fit. The floor prefers the clause the kernel can refuse.

**Rung 3 -- the witness.** `harb tick`, a program in its world as `harb
own` and `harb reach` are: it runs its declared period with an absolute
timer, measures how late each wake was and how long each step took, and
prints the worst and the distribution over N periods -- its last line
the verdict against the deadline it was declared. *In the emulator the
numbers are the emulator's*, as the clock in TIME-1 was: QEMU's
translation keeps no time, so the lens says `measured, unjudged` and the
pin holds no number; the first real number is a board's, which makes the
Pi kit (OS-5, parked on hardware) a purchase with a second reason.
*BREAK IT:* the same loop without its reservation, beside a greedy
neighbour on the same core: the worst wake goes from microseconds to
whatever the neighbour leaves. *Buys:* the difference between a promise
and a measurement, which is the only thing a real-time claim is.

**Rung 4 -- the safe state.** What the floor can promise about liveness
is a quarter of a second (PID 1's loop) and a hardware watchdog whose
countdown is seconds. A motor needs an answer in milliseconds. So the
safe state of an ACTUATOR is never the hosted tier's: it is the body's,
where the loop runs, and the hosted tier's duty is to be HEARD -- a
declared heartbeat from brain to body at a declared period, and the
body's declared act when the beat stops (stop the motors, hold the
brake, open the barrier). On the hosted side the rung is small: the
court refuses a `HEALTH` window below what PID 1 can keep, a reserved
world that overruns is signalled and the transcript says it, and the
watchdog's role does not change. *Judge:* a transcript where the beat
stops and the body says what it did; in the emulator, the body is
MicroRing's simulator. *Buys:* the one property an autonomous system
cannot be without, placed where it can be kept.

**Rung 5 -- the edge schedule.** The edge profile gains timing: on a
SERVICE, `EVERY` (MicroRing's own `:every`, in milliseconds), a
`PRIORITY` (ZinOS Edge's, 0 the highest) and a `WORST` -- the worst-case
time its author declares for one step. ZinOS Edge's design
(`zin/doc/design/ZINOS_EDGE_DESIGN.md` §1.1) is already a cyclic
executive: cooperative, priority-ordered, tick-driven, no preemption, at
most sixteen tasks bound at compile time, no heap after boot, and its
own sentence: *"This makes worst-case execution time statically
analyzable."* The court does that analysis in the only form it can read:
in every frame, the steps due must fit the frame (the sum of their WORST
no more than the tick), or the machine is refused before any flash is
written. `harb project` carries the schedule: the judgment handlers
(tens of Hz) stay Ring, as `robotics.md` says; the muscle (kHz) is the
substrate's compiled code, named by the declaration and not written by
it. *Judge:* MicroRing's simulator with a tick-overrun counter that is
read, as PRJ-2 reads its consumer; then the board. *Buys:* hard real
time where hard real time is possible, with "not an RTOS" intact: the
loop is still the scheduler, and now the loop has a declared schedule.
*What it touches:* MicroRing's own scope statement -- "hard-real-time
control loops -- out of scope" (`vision.md` §3) and `robotics.md`'s
"multi-axis coordinated motion control: out of scope" -- which is the
author's to widen and that desk's to build. The floor can only declare
the seat.

**Rung 6 -- the robot as a set.** A fleet file with two kinds of member
and one new kind of link: a hosted brain, an edge body, and the WIRE
between them (serial, CAN, USB, Ethernet -- declared, with the heartbeat
on it), judged by the fleet court for the states no single machine can
be in: a body with no brain to hear, a brain beating on a wire nobody
listens to, two bodies on one wire. The trial rule of the set: a body
does not move while its brain is in trial (AB-1 at the scale of a
robot). Many robots are the cloud ladder's rungs 5 and 6 (rollout in
waves; the witness world that collects every record). *Judge:* the
brain in QEMU, the body in MicroRing's simulator, one wire between them
-- the first time the court boots two PROFILES together. *Buys:* a
robot that is files: the brain's machine, the body's machine, the pack
that carries the solution's worlds, the fleet that names the wire.

## 5. What is not built, by doctrine, and what this analysis refuses

- **No RTOS.** No thread API, no priorities an application declares,
  no second kernel. A reservation is a budget, declared by the solution
  and held by the kernel; a schedule is a declaration, judged by the
  court. The refusal of 2026-09-12 stands.
- **No interpreter in the loop.** At kHz, MicroRing's own measurement
  of its seam (`performance.md`: `Get(:pin)` 3.6 µs, `Set` 6.2 µs,
  `Toggle` 19.8 µs on the desktop runtime) puts one pin operation at a
  measurable fraction of a period, and a collector's pause is not
  bounded by anybody. The muscle is compiled code -- Zig today, Haro's
  compiled subset when it exists -- and the judgment is Ring or Luau at
  tens of Hz. That is `robotics.md`'s line, kept.
- **No certificate.** A declared machine's evidence -- the file, the
  court's refusals, the pinned transcript, the measured worst case, the
  signed record -- is the kind of evidence a safety case wants, and is
  not one. IEC 61508, ISO 13849 and ISO 26262 are somebody's, never this
  repository's, and no page may say otherwise.
- **No number from the emulator.** QEMU's translation keeps no time. A
  latency the emulator measured is reported as the emulator's, as TIME-1
  reports the emulator's clock, and the first number comes from a board.
- **No ROS.** `robotics.md` refuses ROS2-class industrial robotics for
  MicroRing; this floor neither refuses nor builds it. A ROS node is a
  program, and a program is a world that declares what it needs; whether
  one ever runs on a declared machine is a solution's question, not the
  floor's.
- **Nothing here exists.** Six rungs, zero built. What exists is what
  they stand on: ceilings held by the kernel (BDG-1), a liveness window
  (HLT-1), the floor's own refusals (SYS-1), the edge projection
  (PRJ-1, PRJ-2), the fleet court (FLT-1, FWD-1), the machine's own
  judge (JDG-1), and a kernel tree that already carries the real-time
  model and the deadline scheduler.

## 6. The rulings this asks for

Numbered, so each can be answered in one word, and none is taken on
anybody's behalf:

1. **The scope.** Firm real time on the hosted profile and hard real
   time at the edge, as two tiers of one declaration (§1) -- or one of
   the two only. The name of the thing on any page: never "RTOS", by the
   standing refusal; "a timed machine" is this document's word and a
   proposal.
2. **MicroRing's scope.** Rung 5 asks that desk to take what its vision
   refuses by name (hard-real-time loops, coordinated motion). Whose
   seat is the kHz compiled muscle: declared here, built there -- as the
   board and the pins are today -- or elsewhere? This ruling reaches
   another repository and is routed through Central only after the
   author's word.
3. **The reservation's shape.** `SCHED_DEADLINE` (period, deadline,
   runtime; refused by the kernel when it does not fit) as the floor's
   only shape, with `SCHED_FIFO` priorities refused -- or both.
4. **The kernel as a machine property.** A machine with any reservation
   is a `PREEMPT_RT` machine for every world on it, with the cost named
   in rung 1 -- or a declared `TIMING` on the MACHINE, chosen on purpose.
5. **The deny list, now.** Whatever is ruled above, the floor's own
   refusals should name the scheduling calls: a priority is the floor's
   to set and never a world's to take (SYS-1's own sentence). This is a
   repair of today's floor, independent of the direction, and the one
   item this analysis recommends regardless.
6. **Haro's profile.** A compiled, allocation-free subset for control
   loops, a bounded collector elsewhere, `mlockall` as the runtime's act:
   the runtime's desk's work, named here so that the floor's reservation
   is not a promise made to a runtime that cannot use it.
7. **The board.** The first latency number needs hardware; OS-5's kit
   is a purchase. Whether this direction is reason enough to un-park it.
8. **The robot's declaration.** zin's Zrb as the Softanza-altitude
   declaration a robot projects from, and Aïcha's worlds outside the
   deadline path by construction (§3) -- or another placement.

## 7. Where it stands

Written 2026-10-13 as the analysis the author asked for, in the
repository so that it can be read against the code and amended beside
its own sentences. *Ruled the same day* (STZ-OS-RULING-17,
`PROVENANCE.md`): the eight items of §6 are taken as this document
recommends -- both tiers in one declaration, MicroRing's half declared
here and built there, `SCHED_DEADLINE` only, the timed kernel derived,
the deny-list repair first, Haro's constraint handed over, the board his
to buy, Zrb and Aïcha as drawn. The finding of §2 -- a world that runs
as the machine could take a real-time priority the floor never granted
-- was closed the same day (PRI-1, `experiment/PROTOCOL.md`): the five
scheduling calls are the floor's refusals, the witness tries one from
inside every world of `qemu_confine`, and the floor line says it.

**Rungs 1 and 2 are built, the same day (TIM-1, `experiment/PROTOCOL.md`),
and four things in §4 were written before the kernel was asked and are
corrected here beside their sentences.** The timed kernel is derived
from any reservation and READ BACK -- `boot: timed -- the kernel is
PREEMPT_RT and its timers resolve 1 ns, as it says of itself` -- and the
reading was needed twice before the line was true: the PC's firmware
lists one processor in its MP table whatever `-smp` says (the second
cpu is only in the ACPI tables), and the emulated TSC skews under TCG
until the kernel falls back to jiffies, 4 ms, which is no
high-resolution timer; ACPI, the HPET and a bounded wait for the
clocksource's verification are what the derivation carries now. The
reservation is as §4 drew it, with these differences: (1) the court's
bound is **90 %** of a core and not 95 -- the kernel admits 95 and,
since 6.12, holds 5 of them in the same ledger for the ordinary tasks'
own deadline server, which the first boot of `qemu_deadline` found when
the second of two worlds asking 95 together was refused at the act; the
court counts as the kernel counts (2^20ths, truncated), because a bound
in another arithmetic admits a set the kernel then refuses at the edge;
(2) a period is bounded by the kernel's own `sched_deadline_period_min_us`
and `_max_us`, 100 us to 4194304 us, and not by this document's ten
seconds; (3) the partition is one per reserved CORE, never per world,
because a root partition's cpus are exclusive -- the worlds reserved on
a core sit in groups beneath its partition; and an `isolated` partition
would not do, because the kernel admits a deadline task only against the
root domain it stands in, and every isolated core shares the default
one; (4) a reserved world MAY declare `process`: the reservation is set
with reset-on-fork, so what it spawns runs unreserved and a fork is not
refused -- the reservation is the main thread's, as ruling 17 told
Haro's desk. A world that is a USER gets its reservation before it
becomes that user, which is the one way an ordinary user ever holds one.
The third world of §4 ("asks for more than there is, refused by the
kernel") is not in the pinned machine, because the court refuses it
first; it is a mutant of the probe (`experiment/deadline_probe.sh`),
where the court's bound is put back to 95 and the kernel refuses the
second world at the act. What rung 2 does not show is any latency: the
emulator is a program on a host, and its time is the host's. Rung 3,
the witness, is the next session.
