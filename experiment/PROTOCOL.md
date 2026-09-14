# LRN-1 — the guided tour, and why a tutorial needs a judge like everything else

Asked for by the author: a way to SEE what was built, didactically,
rather than read twenty-four protocol entries in reverse order.

## Where it lives, and why not in a document

Everything here is judged by something that would notice if it drifted:
the grammar by its fixtures, the boot by its own expectation, the
transcript by its pin. A tutorial written as prose has no such judge. It
says "run this and you will see that", and nothing checks that the file
still exists, that the verb is still spelled that way, or that the line
it tells you to look for is still printed.

So the curriculum is a table in `src/learn.zig`, beside the verbs it
teaches, and every lesson declares the paths it names. `stzos learn
--check` walks them, and **`zig build court` runs that check** -- so a
lesson pointing at a machine somebody renamed turns the court red in the
commit that renamed it.

Probed, as the doctrine requires: run `stzos learn --check` from outside
the repository and it names every missing path and exits 1; from inside,
it exits 0. A judge that cannot convict is not judging.

## The shape of a lesson

Six fields, and the fourth is the whole point.

```
  THE QUESTION       what you do not yet know
  RUN                one command, copy-pasteable
  LOOK FOR           the exact lines that answer it
  BREAK IT           a change you make so the machine convicts YOU
  THE LAW IT PAID FOR   the doctrine sentence, verbatim
  THE FULL STORY     where the account lives
```

**Break it** is why this is a tutorial and not a tour. A guarantee you
have only seen SUCCEED is a claim; one you have watched refuse you is
evidence. That is the same argument IDN-1 made about a signature nobody
tried to break, turned on the reader: add a shell to a RUN and watch the
grammar refuse it by name; change a word in a pinned transcript and
watch the court produce a diff; give a confined world the capability it
lacked and watch the interface appear.

## Eighteen lessons, six acts

```
I.   THE DECLARATION      a machine is a text file, judged before anything runs
II.  THE BOOT             it narrates, it judges ITSELF, and a pin judges that
III. WHAT A WORLD MAY DO  the envelope, the floor, whose storage, the budgets, the reach
IV.  WHO A DEVICE IS      the key, the signed record, attribution by a stranger
V.   THE NETWORK          the box as its link's server of names; facts about a SET
VI.  THE FLAGSHIP         four card boots, a held trial, and the four promises
```

The acts are ordered so that a reader who stops half way has finished a
whole part of the story, and a unit test enforces that an act never
returns after another has begun.

## What runs, and what does not

`stzos learn <n> --run` spawns THIS binary with the lesson's own words,
so what executes is exactly what the lesson printed rather than a
paraphrase of it. It works for the four lessons whose command is a verb
of this binary. The boots are WSL scripts and are never spawned from
here: the machine that runs them is not the machine you type on, and
pretending otherwise would be the first lie in a tutorial about not
lying.

## The law this pays for

**A tutorial is a claim about the system, so it is judged like one.**
Anything that tells a reader what they will see must fail loudly when
that stops being true.

---

# THR-1 — whose thread it is: the question dissolved rather than answered

The twelfth act of 2026-09-14, and the last named seam in the envelope.
It was left open for five seats because the question as asked has no
answer, and the seat is what happens when you notice that.

## The question that could not be answered

stzlib's `threads` capability says whether the WORLD may create threads.
NS-1 built the machinery to refuse `clone(CLONE_THREAD)` and then
deliberately did not wire it, because the kernel cannot tell a thread the
Luau script asked for from one stzr made for its own housekeeping.
Refusing them alike would punish the runtime for the world's
declaration. That is a real objection and it does not go away.

## The question that can be

Not *who asked for this thread* but *how many tasks will this machine
hold for this world*. The kernel answers that one exactly, and it is the
same shape as `MEMORY` and `CPU`: a ceiling the declaration sets and the
kernel holds.

```
DEFINE SERVICE swarm AS (
  RUN ["/stzos", "swarm", "12"],
  TASKS 6,
  NEEDS [process, filesystem]
) RATIONALE "..."
```

`TASKS n` becomes cgroup v2's `pids.max`, which counts **processes and
threads together**. Together deliberately: a thread and a process are one
`clone` flag apart and the kernel keeps one number, so a floor that
billed them separately would be inventing a distinction the kernel does
not make. The runtime's housekeeping counts against the ceiling, which
is right -- the machine is sizing the WORLD, and stzr's threads are this
world's threads.

## So the capability stays where it was

`threads` is the world's API surface and the runtime's to refuse. It
asks WHO ASKED, which only stzr knows. `TASKS` asks HOW MANY, which only
the kernel knows. They are different questions and each belongs to
whoever can answer it -- which is the whole resolution, and the reason
this floor will never enforce `threads` at the kernel.

## Judged

```
boot: budget -- modest 64 MiB and 50% of a core, swarm 6 tasks, greedy 32 MiB; the kernel holds the ceiling, not the world
boot: start swarm -- pid N -- /stzos swarm 12
swarm: 5 tasks made, and the kernel refused the next (AGAIN): this world is as many as the machine agreed to hold
boot: swarm (pid N) exited 0
```

Five children plus the world itself is six, which is what was declared.
EAGAIN rather than a kill: a ceiling on how many, not a refusal to be --
and the neighbours never felt it, exactly as the memory ceiling of BDG-1
behaves one row below in the same transcript.

**107/107** fixtures, from 104.

## The defect, and it is the third of its kind

The first boot printed `swarm 6 tasks` and the world made all twelve.
`pids.max` had been written on a group nobody was in: `cgroupJoin`
returned early unless the service declared MEMORY or CPU, a guard
written before `TASKS` existed.

That is the third time in two days a guard has been narrower than the
thing it guards -- NS-1's refusal gated on `confined()`, SYS-1's gated
the same way, and now this. The pattern is always the same: a new
dimension is added to a policy, and a condition written for the old
dimensions silently excludes it. **When a policy grows a dimension,
grep for every condition that enumerates the old ones.**

## The law this pays for

**When a question cannot be answered, check whether it is the right
question.** "Whose thread is this" has no answer at the kernel and
never will. "How many tasks may this world have" has an exact one, it
is the question a floor actually needs, and it was available the whole
time.

---

# SEE-1 — per-world sight of the machine's storage: `filesystem` stops being all or nothing

The eleventh act of 2026-09-14, and the first envelope seat that needed
a CLAUSE. The four before it were derived from `NEEDS`, because `NEEDS`
already knew the answer. Which mounts a world keeps is information no
existing clause carries, and inventing a derivation for it would have
been guessing.

## The shape

```
DEFINE SERVICE ledger AS (
  RUN [...],
  NEEDS [process, network, filesystem],
  SEES [data]
) RATIONALE "..."
```

`NEEDS [filesystem]` is the GRANT. `SEES` NARROWS it. That is the whole
semantics and it settles the awkward question about silence: saying
nothing does not widen anything, because the world already declared the
capability, so a world with `filesystem` and no `SEES` keeps every
declared mount -- which is what every machine written before this clause
already did, unchanged.

An empty `SEES` is refused rather than meaning nothing: a world that
wants no storage declares no `filesystem`, and one that wants all of it
says nothing here.

## What it refuses

Five, and the first is the one that keeps the clause honest:

- `SEES` without `filesystem` in `NEEDS` -- a world cannot choose sight
  of storage it never asked to touch;
- a mount this machine does not declare;
- an empty list;
- one mount named twice;
- a machine that declares no `MOUNT` at all, where there is no sight to
  apportion.

**104/104**, from 98.

## The check that had to move

The mount names could not be validated where the clause is read:
`MOUNT`s are parsed AFTER `SERVICE`s, so the service loop would be
asking about something the parser had not read yet. The capability
check, the empty check and the duplicate check happen in the loop; the
"is there such a mount" check is a second pass once the mounts exist.
A refusal must be able to name what the declaration actually contains.

## Judged

`qemu_confine` grew to six worlds and needed a SECOND mount to make the
choice a choice -- with one mount a world either sees the machine's
storage or it does not, and there is nothing to apportion. The two new
worlds are exact mirrors:

```
boot: start ledger ...
confined: /data -- mounted here: this world can see the machine's storage
confined: /var/log -- an empty directory and nothing mounted on it: ...

boot: start caisse ...
confined: /data -- an empty directory and nothing mounted on it: ...
confined: /var/log -- mounted here: this world can see the machine's storage
```

Same machine, same binary, same capability granted to both. The only
difference between them is which mount each one named, and neither can
read the other's. That is the shape a business world wants: the till's
own data, and no sight of what it has no business reading.

The `stzos plan` output names the narrowing too (`-- sees [data]`), so
an auditor learns which world holds which storage without opening the
machine file.

## The law this pays for

**Derive while the declaration already knows; add a clause when it does
not.** Four seats of envelope came out of `NEEDS` without a word of new
grammar. This one could not, and pretending otherwise -- deriving
"which mounts" from some proxy -- would have been a guess wearing a
derivation's clothes.

---

# KCACHE-1 — one kernel per configuration, not one per architecture

Not a seat: a repair to the court's own instrument, made because the
SYS-1 regression took twenty minutes and the author asked why.

## What it was

`os2_image.sh` kept one kernel tree per architecture and configured it
afresh for whichever machine was building. But a machine carries the
kernel ITS OWN declaration needs, so every machine asks that tree for a
different kernel -- 502 options for `qemu_hello`, 634 for `qemu_egress`
-- and each one reconfigured and rebuilt what the machine before it had
just finished building.

The measurement that names it, from the SYS-1 regression in the order it
ran:

| machine | kernel build |
|---|---|
| qemu_hello | 1m16 |
| qemu_budget | 1m31 |
| qemu_identity | 2m07 |
| **fleet_temoin** | **0m06** |
| qemu_egress | 2m23 |
| makeen_qemu | 3m04 |
| makeen_box | 3m13 |

`fleet_temoin` wants exactly the 559 options `qemu_identity` wants and
ran straight after it, so the tree was already configured that way and
`make` had nothing to do. One row got a cache hit by accident of
ordering; the others paid full price for a kernel that had existed an
hour earlier.

## What it is now

One SOURCE tree per architecture, extracted once. One BUILD directory
per CONFIGURATION, keyed by the first twelve hex of the fragment's
sha256, built out-of-tree with `make O=`. A configuration is built once
and reused; two machines that want the same kernel share it; and the
boot log says which it got:

```
kernel cache: MISS x86_64-f4e24d5fe4b5 -- first build of this configuration
real    1m49.423s
kernel cache: HIT x86_64-f4e24d5fe4b5 -- this configuration is already built
real    0m6.611s
```

Then the test that matters, because the old layout's whole failing was
that machines evicted each other: run `qemu_egress` in between, and come
back.

```
qemu_egress   MISS 2m25.615s
qemu_hello    HIT  0m4.756s
```

And the whole regression, twice, every run judged against its pin:

| machine | pass 1 | pass 2 |
|---|---|---|
| qemu_hello | MISS 1m50 | HIT 0m05 |
| qemu_budget | MISS 1m45 | HIT 0m05 |
| qemu_identity | MISS 1m59 | HIT 0m05 |
| fleet_temoin | HIT 0m05 | HIT 0m05 |
| qemu_egress | MISS 2m13 | HIT 0m07 |
| makeen_qemu | MISS 2m57 | HIT 0m06 |
| qemu_confine | MISS 2m10 | HIT 0m08 |
| makeen_box | MISS 3m11 | HIT 0m04 |
| **total** | **16m10** | **0m45** |

Sixteen minutes of kernel builds becomes forty-five seconds, and all
sixteen runs matched. `fleet_temoin` is a HIT on the second row of the
FIRST pass, which is the key fix showing its work: it shares
`qemu_identity`'s configuration and no longer builds it again.

The out-of-tree build produces the same kernel; only where it is kept
has moved.

## The key is what the fragment ASKS FOR, not the file

The first key was the sha256 of `kernel.fragment`, and it was wrong in a
way the cache itself exposed within minutes: `qemu_identity` and
`fleet_temoin` want byte-identical options and got two separate builds,
because the derived fragment opens with a comment naming the machine it
came from. Hashing the file hashed the comment.

The key is now the CONFIG lines alone -- keeping `# CONFIG_X is not
set`, which looks like a comment and is a setting -- and the two collide
as they should.

## Why the sources moved too

`make O=` refuses a source tree that was ever built IN -- it wants
`mrproper` first. The existing `$K/<arch>` trees are dirty from every
in-tree build since OS-2, so the sources now live at `$K/src/<arch>`
and get extracted clean. **The old `$K/<arch>` trees are superseded and
can be deleted**; about 7 GB, and nothing reads them any more.

## What it does not change

The rule it exists to serve: a machine still carries the kernel its own
declaration needs, and nothing was merged into a common superset to make
the cache cheaper. Two machines share a build exactly when they ask for
the same thing, which is a fact about their declarations rather than a
convenience arranged here.

---

# SYS-1 — the syscall surface: the machine is not a world's to change

The tenth act of 2026-09-14, and the first of the envelope seats that is
NOT derived from `NEEDS`.

## Why this one is different

The three before it all asked the same question: *what did this world
declare?* This one asks a different one: *what is a world, on this
floor?*

The machine's own law says there is no shell, no package manager and no
service manager, and that the declared machine IS the system. A world
computes and talks to what it declared. It does not remount the
filesystem, set the clock, load a kernel module, rename the host, build
itself a new envelope, read another process's memory, or reboot the box.

No clause grants those, because **no declaration should ask**. So they
are refused to every world on every machine, with EPERM, whatever its
`NEEDS` say -- and `qemu_confine`'s `open`, which declares `process`,
`network` and `filesystem` and is held to nothing on its own account, is
refused them exactly like the others.

## The list, and one absence

Twenty-five calls in four groups: the filesystem tree (`mount`,
`umount2`, `pivot_root`), the kernel (`init_module`, `finit_module`,
`delete_module`, `kexec_load`, `kexec_file_load`), the machine's own
life and identity (`reboot`, `settimeofday`, `clock_settime`,
`adjtimex`, `clock_adjtime`, `sethostname`, `setdomainname`), and the
envelope and the plumbing (`unshare`, `setns`, `ptrace`, `swapon`,
`swapoff`, `bpf`, `syslog`, `acct`, `mknod`, `mknodat`).

A call absent on an architecture emits no instruction at all, so the
filter never tests a number that means something else there.

The absence worth naming: this is **not** a default-deny allowlist. That
would be the strong form, and it would mean enumerating everything stzr
needs on two architectures and being wrong somewhere nobody notices
until a world dies in a restaurant. What is claimed is exactly what is
built: a named, closed list of things a world may not do, not a proof
that everything else is safe.

## The order that makes it possible

The filter is installed LAST, after the unshares that build the
envelope. That is why it can refuse `unshare` and `mount` -- PID 1 has
already used them, and the world never will.

## Judged

Two new tests beside the code: a world that declared everything still
carries the floor's refusals, and every call in the list appears on
every filter whatever the world declared. And the boot says it once,
per machine rather than per world, because it is a fact about the floor
and not about any declaration:

```
boot: floor -- the machine is not a world's to change: none may mount or unmount, set the clock, load a module, rename the host, make or enter a namespace, trace another process, or reboot the box
confined: the floor -- refused by the kernel (EPERM): this world cannot change the machine it runs on
```

The witness TRIES it rather than reporting it, and the call it tries is
`unshare` -- chosen because if the filter is not there, all that happens
is the world gets a mount namespace of its own and exits. **A witness
must not damage the machine in the case where the guard it is testing
has failed**, which rules out trying `reboot` to prove reboot is
refused.

## Two defects, and neither was in the filter

Both were found by REFUSING TO PIN A TRANSCRIPT WITHOUT READING ITS
DIFF, which is the only reason this entry is not a lie.

**The kernel could not build the filter on a machine with no network.**
`CONFIG_SECCOMP_FILTER depends on HAVE_ARCH_SECCOMP_FILTER && SECCOMP &&
NET` -- the kernel builds its filter engine on the BPF core, which lives
under `NET`. So `qemu_hello`, which declares no network at all, got
`EINVAL` from `seccomp()` and PID 1 refused to start a world it could
not confine. Three of its worlds did not run. That refusal is the NS-1
law doing exactly its job, and it is the second time a namespace or a
filter has turned out to depend on `CONFIG_NET` -- the first was
`NET_NS`, three seats ago. A machine with no wire now gets `CONFIG_NET`
anyway when it needs the floor's refusals: a machine carries the kernel
its own declaration needs, and since this seat every declaration needs
them.

**And the worse one: the refusal was guarded too narrowly.** PID 1 only
refused to start a world when `held.confined()` -- when the world's own
`NEEDS` had asked for something to be taken away. But since this seat
EVERY world has an envelope, so on `qemu_identity`, whose worlds declare
everything, the filter failed silently, the boot printed

```
boot: floor -- the machine is not a world's to change: ...
```

on its console, and nothing at all was behind it. The machine announced
a guarantee it had not kept -- the NS-1 defect, in its third incarnation
and its best hiding place yet, because the transcript looked perfect and
the boot judged itself a match. The guard is now simply "the kernel
could not build this world's envelope", with no condition on whose
account it was being built.

## The law this pays for

**Some things are refused by what a world IS, not by what it declared.**
When no declaration should ever ask for something, do not add a clause
that could grant it -- refuse it to everyone and say so once.

**And: a pin is not a record of what happened, it is a claim that what
happened was right.** Copying a transcript over its expectation without
reading the diff turns a broken world into the new definition of
correct. Every re-pin in this seat was diffed against a checker that
allows exactly two changes -- the floor line appearing and the judged
count moving by one -- and four pins made before that checker existed
were reverted.

## What it cost, measured

The eight-machine regression took about twenty minutes, and the kernel
is all of it. One row of the timings says why:

| machine | kernel build |
|---|---|
| qemu_hello | 1m16 |
| qemu_budget | 1m31 |
| qemu_identity | 2m07 |
| **fleet_temoin** | **0m06** |
| qemu_egress | 2m23 |
| makeen_qemu | 3m04 |
| makeen_box | 3m13 |

`fleet_temoin` wants a kernel with exactly the 559 options
`qemu_identity` wants, and it ran straight after it, so the shared
tree was already configured that way and `make` had nothing to do.
Every other machine paid a full reconfigure because the machine before
it had left the tree configured for something else. That is the whole
cost, and KCACHE-1 turns every row into the `fleet_temoin` row.

---

# PID-1 — the process table: a world that never asked for processes is alone in one of its own

The ninth act of 2026-09-14, and the last of the three that close "what
a world can see". Still no clause.

## What `process` means, stated once

stzlib's capability is *spawn and manage*, and managing is inspecting
and signalling as much as starting. So a world that never asked for
`process` now gets none of it: it cannot create one (NS-1), and it
cannot SEE or signal one either. The pids of the other worlds do not
exist in its table, so they cannot be named, let alone killed.

## The trap in the middle of it

`unshare(CLONE_NEWPID)` does **not** move the caller. It makes the
caller's future CHILDREN the inhabitants of a new table. A world that
unshared and then exec'd would still be standing in the machine's own
table, with a guarantee printed about it and nothing behind the
guarantee -- the NS-1 defect again, wearing a different hat.

So the child forks once more. The grandchild is pid 1 of the new
namespace and becomes the world; the process left behind is a STAND-IN
that exists only to carry the world's fate back unchanged:

- an exit code exits,
- a signal is re-raised on itself,

so `boot: kds (pid N) exited 0` and the killed-by-the-kernel line the
BUDGET seat depends on both stay true through a process nobody declared.

And `/proc` is remounted inside, or the world would read the machine's
table through the mount it inherited and see every other world. That is
why the mount namespace is now asked for by EITHER reason -- the storage
(MNT-1) or the table -- and asked for once.

## What made it safe to do at all

PID 1 never signals a world. It spawns and it reaps, and nothing else,
so the signal shielding a namespace's init acquires changes nothing
here. The kernel's own OOM kill, which the BUDGET seat relies on, is
SIGKILL from an ancestor namespace and reaches a namespace init
regardless. Both checked before a line was written.

## Judged

`still` declares `network` and `filesystem` and not `process`, and gives
four independent answers, each from one word above it:

```
confined: eth0 -- present: this world shares the machine's network
confined: processes -- this world is pid 1 and no other process exists here: a table of its own
confined: /data -- mounted here: this world can see the machine's storage
confined: fork -- refused by the kernel (EPERM): this world cannot start another process
```

`exited 0` came back through the stand-in unchanged.

And `makeen_box` again: both its worlds declare `NEEDS [network,
filesystem]`, so both are now daemons that are pid 1 of their own
tables, behind a stand-in, with a remounted `/proc`. **All 125 lines
across four card boots match** -- they came up, signalled ready, held
their health windows, and the trial committed. The only line that
changed in the whole file is the wording of the confinement itself.

## The law this pays for

**A namespace the caller does not enter is a namespace nobody is in.**
`unshare` is not `enter`: check which side of the call the guarantee
lands on, and if it lands on the children, make one.

---

# MNT-1 — the mount namespace: a world that never asked for the filesystem does not get the machine's storage

The eighth act of 2026-09-14, and the other half of the envelope NS-1
opened. Still no clause.

## What is taken, and what is deliberately not

A world whose `NEEDS` omits `filesystem` runs in its own mount namespace
with every DECLARED `MOUNT` detached. It keeps the image it was built
from, because its binary is a file and a world with no files is not a
world. It loses the machine's STORAGE -- which is where everything worth
keeping from a world lives: the device key, the signed boot record, the
business data.

That line is the whole design. The profile's implicit `proc`, `sysfs`
and `devtmpfs` stay: they are the machine's plumbing, not its storage,
and a world that cannot see `/proc` is a world that cannot run.

## The safety step that is not optional

Before any detach, the tree is made `MS_REC | MS_PRIVATE`. Without it
the umounts PROPAGATE BACK to the machine, and a single confined world
takes `/data` away from every other world and from PID 1 itself. A mount
namespace that shares propagation is not an isolation; it is a way to
break the box from inside a world.

## Judged

`machines/qemu_confine.machine` grew to four worlds and three questions,
and every cell is explained by the line above it:

```
                      eth0        /data       fork
  sealed   no network  not there   mounted     permitted
  still    no process  there       mounted     refused, EPERM
  open     everything  there       mounted     permitted
  blind    only process not there  NOT MOUNTED permitted
```

`blind` asked for nothing but the right to run, so it gets nothing but
that. It is the world a sovereignty brief wants for anything handling
data it must not be able to send anywhere -- DIKO's ESC6 read from the
other side: not "may not leave the perimeter" but "has nowhere to send
it from and nothing to send".

## The defect, and it was the witness rather than the mechanism

The first run reported `/data -- there` for `blind` and the promise
looked broken. It was not: `/data` is a DIRECTORY in the image, put
there so PID 1 has somewhere to mount onto, and it stays after the
detach. `access()` answers about the directory and says nothing about
what is mounted on it.

The honest question is the one `mountpoint(1)` asks: a path is a
separate filesystem exactly when its device id differs from its
parent's. The witness now compares them with `fstatat` -- `stat` does
not exist as a syscall on aarch64 at all -- and says which of the two
things it found:

```
confined: /data -- mounted here: this world can see the machine's storage
confined: /data -- an empty directory and nothing mounted on it: this world has a mount namespace of its own and the machine's storage is not in it
```

A witness that asks a question next to the one that matters will report
a kept promise as broken, which costs exactly as much trust as the
reverse.

## One tolerated failure, on purpose

`umount2` returning EINVAL is not treated as trouble. It means nothing
was mounted at that path -- and then the world cannot see the machine's
storage there either, so the promise is kept vacuously. Cascading a
failed boot-time mount into a refusal to start every confined world
would punish the worlds for the machine's own fault.

## The law this pays for

**Ask the question that decides, not the one next to it.** The witness
is part of the evidence, and a witness answering an adjacent question is
a witness giving the wrong verdict with full confidence.

---

# NS-1 — namespaces and seccomp: the kernel keeps the promise NEEDS has been making since the first day

The seventh act of 2026-09-14, and the only one so far that added no
clause at all.

## The promise that was kept by good manners

`NEEDS` has said what each world requires since the first machine file.
The runtime refused what was not granted; the KERNEL handed it over
anyway. A world that never declared `network` could open a socket. A
world that never declared `process` could fork. The declaration was
true about intent and false about the machine.

Here the kernel keeps it instead, derived and never declared:

| the world's NEEDS omits | what the kernel does |
|---|---|
| `network` | it runs in its own EMPTY network namespace -- the interface is not refused, it is not there |
| `process` | `fork`, `vfork` and `clone` without `CLONE_THREAD` return EPERM |

## Why the vocabulary already fit

stzlib's nine capabilities separate `process` from `threads`, and the
kernel separates them at exactly the same seam: one `clone` makes either,
and one bit of its first argument says which. The filter tests that bit,
which is what makes the refusal precise rather than a blanket ban on
`clone` that would break every runtime that threads. A vocabulary
written for a virtual twin turned out to name the distinction the kernel
actually makes.

## The one deliberately NOT enforced

`threads`. A capability says what the WORLD may do, and a thread the
RUNTIME creates for its own housekeeping is not the world asking: stzr
is a process this machine starts, not a program the declaration wrote.
Refusing it a thread because a Luau script never asked for threading
would punish the runtime for the world's declaration. The machinery to
refuse it is built and judged; the seat that decides whose thread it is
is not.

## Judged

`machines/qemu_confine.machine` -- three worlds, one witness, and the
only difference between them is what their own NEEDS say:

```
boot: confine -- sealed has no network of its own, still has no way to start another process
confined: eth0 -- no such interface from here: this world has a network namespace of its own and there is nothing in it
confined: fork -- permitted: this world started another process, and this line is the child speaking
confined: eth0 -- present: this world shares the machine's network
confined: fork -- refused by the kernel (EPERM): this world cannot start another process
```

`stzos confined` asks a sharper question than `stzos reach`: not whether
the machine knows a WAY to an address, but whether the interface EXISTS
from where the world stands. "No such interface" is a different answer
from "no route" in the way that matters -- there is nothing here to be
refused.

And the flagship earned something. `makeen_box` declares `NEEDS
[network, filesystem]` for both its worlds -- no `process` -- so both
now run under a filter that refuses process creation. **All 125 lines
across four card boots match**, which means stzr genuinely does not
fork: the declaration was TRUE, and the kernel now holds it.

## Three defects, and the second is the serious one

**The witness said everything twice.** A fork copies the buffer as well
as the process, so the child's flush re-emitted what the parent had not
yet written. Flush before forking.

**The confinement was ANNOUNCED and did nothing.** The first run printed
`sealed has no network of its own` while sealed had the whole network:
`unshare` failed, `apply` recorded the failure in a field nobody read,
and the boot went on. That is the exact defect this repository exists to
refuse -- a claim the machine did not keep, in the transcript that is
its evidence. PID 1 now does not start a world whose envelope it could
not build: it says so and exits 125, the boot differs from its
expectation, and a trial holds.

**And the reason it failed was a claim that was empty anyway.**
`unshare` answered EINVAL because `CONFIG_NET_NS` depends on
`CONFIG_NET`, which a machine with no declared network never enables.
The right fix was not to force the option on: a machine with no wire has
no network to keep a world off, so there is nothing to refuse and
nothing to say. `qemu_hello` went back to the transcript it has had
since the first day, which is the correct outcome and looks like no
work at all.

## The law this pays for

**A promise the machine announces and cannot keep is worse than one it
never made.** When the mechanism behind a declared guarantee fails,
refuse the act and say so; never print the guarantee and continue.

---

# HDW-1 — the hardware clause: the last fact about a deployment that lived in a shell script

The sixth act of 2026-09-14, and the smallest. It deletes a constant.

## What was wrong

`machines/makeen_names.machine` promises `192.168.10.40` to a peer
identified by a hardware address. `machines/caisse_makeen.machine` is
the till that will claim it and says nothing about its own hardware.
The only thing connecting the two was this, in `experiment/os6_names.sh`:

```
TILL_MAC=52:54:00:12:34:61        # the `caisse` peer, declared in the box
```

A comment. In a shell script. In a repository whose entire argument is
that a fact about a deployment belongs in a declaration a court can
read — and the fleet court, one seat old, could not check the one
correspondence that decides whether the deployment works at all.

## Where it belongs, and why not the machine

On the MEMBER, beside `KEY`. A machine file is a DESIGN and one design
images many devices; a hardware address belongs to one of them. That is
exactly the distinction the key already draws: both are facts a
DEPLOYMENT learns, never facts a design states.

## What the join buys

Five refusals that hold the promise and the machine against each other,
none of which any single file can fail:

- a device that asks on a served link and is in the server's register
  under no peer at all -- it will never get an address, because there is
  no pool to fall back on (FR16);
- a device the server promises one address and which takes another
  itself (FR17);
- the server appearing in its own register, which would be a machine
  asking itself for an address it already has (FR18);
- two members claiming one device (FR15), and hardware that is a word
  rather than an address (FR14).

**22/22**, from 16/16. And the roll now says the join out loud:

```
caisse -- caisse_makeen (caisse_makeen.machine, asks) -- 52:54:00:12:34:61, promised 192.168.10.40 as caisse
```

A `PEER` no member claims is deliberately NOT refused. The kitchen
printer is a declared peer of the box and will never be an stzos
machine; the fleet checks the members it has and says nothing about the
rest of the wire.

## The proof is a pin that did not move

`experiment/os6_names.sh` now reads both addresses from the declaration
through `stzos fleet <file> hardware <member>`. The 66-line names
transcript **matched unchanged** on the first run afterwards: the
declaration supplies exactly what the constants did, and now a court can
check it. A seat whose whole result is that nothing visible changed is
the right shape for this one.

## The law this pays for

**A fact about a deployment lives in a declaration, or it is not a fact
anyone can check.** When one turns up in a script, move it and delete
the constant -- do not add a second place that has to agree.

---

# FLT-1 — the fleet court: machines judged together, and one device's record verified by another

The fifth act of 2026-09-14, and the one the IDENTITY and JOURNAL seats
were waiting for.

## The gap it closes

A device makes its own Ed25519 key on first boot and never sends the
private half anywhere (IDN-1). It signs its own boot record with it
(JRN-1). Put those together and you get a record only its author can
verify — which is attribution nobody else can test, and the IDENTITY
seat already ruled on that shape of thing: a signature nobody tried to
break is a claim, not evidence.

A fleet closes it with arithmetic rather than trust. It records each
member's PUBLIC key, which proves nothing about anyone else and may be
held by anyone, so **any holder of the fleet file can verify any
member's record** and no secret takes part in the act.

## Why a second file and not a bigger one

Every check until now could be made by reading one machine. These
cannot be made that way at all:

- two boxes that each declare themselves the server of `makeen` are each
  a faultless machine, and together they are a network where two
  machines hand out the same addresses and neither is wrong;
- two machines that each take `192.168.10.7` are each correct alone;
- a till that asks for an address on a link nobody serves never gets
  one, and nothing in its own file is wrong.

Facts about a SET belong in a file about a set. It is the SAME language
— same tokenizer, same clause machinery, same refusal channel — and a
file is judged by which kinds it may contain. A machine file declaring a
`FLEET` is refused by name; a fleet file declaring a `MACHINE` is
refused by name.

`src/fleet.zig`'s third unit test says it best: it declares both
machines successfully, one after the other, and then refuses the fleet
they make.

## Enrolment is not prophecy

A `KEY` cannot be declared before the device that makes it exists. So a
member without one is NOT refused — it is reported, in these words:
*KEEPS A RECORD AND IS NOT ENROLLED: nobody can verify what it signs*.
The court refuses what is wrong; the roll says what is incomplete.

Enrolment stays manual on purpose. A fleet that enrolled whatever key
answered would attribute records to whatever device happened to be
plugged in. The enrolled key implies the fingerprint the device prints
on its own console, so the roll prints it and an operator compares the
two by eye.

## Judged

**16/16** fleet fixtures (`declarative/fleet/fixtures.json`), every
reject a case where each machine is faultless alone. **Three unit
tests** on attribution. And the whole arc on a real device
(`experiment/os7_fleet.sh`, **26 lines** pinned), where the negatives
decide it:

```
verify:     temoin: 1 entry verified against the enrolled key (fingerprint FP1), and no secret took part
tampered:   temoin: entry 1 is not this device's: the entry's own bytes do not hash to the hash it carries
foreign:    temoin: entry 1 is not this device's: this device's key did not sign this entry
unenrolled: temoin has no KEY in this fleet: nobody can speak for its records
```

The device makes a NEW key on every run of that script and the pin still
holds — each distinct key becomes `KEY1`, `KEY2`, … in order of
appearance, so the persistence claim survives and only the randomness is
erased.

## Two defects, one of them old

`stzos attest --export` failed on the device with `cannot read
--export: FileNotFound`: the verb took the first argument as its file
path and a flag is not a path. Fixed by picking the first argument that
is not a flag.

And the normaliser matched `fingerprint [0-9a-f]+` against a transcript
containing `fingerprint after its next boot`, so it read the `af` of
`after` as a fingerprint and wrote a token into the middle of an English
word. Values are now MARKED by `sed` at their exact lengths before `awk`
maps the distinct ones. **The same fragility had been in
`experiment/os2_image.sh` since IDN-1**, unexposed only because no line
there ever put a word after `fingerprint`.

## The law this pays for

**A claim only its author can check is not evidence.** The floor holds
the secret; the fleet holds what anyone may check; and the two never
meet in one place.

---

# NAM-1 — the box as the network's own server of names, and the first time two machines met on a wire

The fourth act of 2026-09-14, and the first one whose proof needed a
second machine.

## The ground, which is not ours

RestoLean's B7 states it from the merchant's side. Many boxes do not
keep their register of leases across a reboot: the kitchen printer
comes back on a different number and somebody re-types it into the
till. Makeen lives with this. It has nothing to do with us, and that is
exactly why it is worth solving — "Makeen would solve a problem he has
today that has nothing to do with us" is the strongest form a floor's
value can take.

The answer B7 names is a box that hands out the addresses itself,
reserves them all, and gives names: `imprimante.makeen`.

## The design is a removal

`DOMAIN` on a NETWORK makes the machine that link's server. `PEER`
declares who is on it. **There is no pool and no range.** The machine
serves exactly the peers declared and nobody else.

So the failure is not handled — it is made impossible to have. The
register of who has which address cannot be lost at a reboot because
there IS no register: there is the declaration, in git, judged by the
court before the image was built. And the lease is offered INFINITE
(option 51, `0xffffffff`), which says the true thing: this address is
this device's because it was declared, not because a timer has not run
out yet.

Two more removals, both of them refusals to lie:

- **No router option.** This machine does not forward, and a box that
  named itself the way out without being one would be lying to every
  device on the link. Forwarding would be an act, and an act is
  declared; there is no clause, so there is no forwarding.
- **No referral.** A name the box does not serve is `NXDOMAIN` — a true
  statement about this network — never forwarded upstream. The box
  speaks for its own link and is silent about the rest of the world.

## Judged by the thing that consumes it

Eight refusals and one accept widened the court to **98/98**. Four unit
tests judge the codec beside the code. But the claim "this box serves
`imprimante.makeen`" is not proved by the box saying so, and PRJ-2
already paid for that law: a generated artifact is judged by what
CONSUMES it.

So `experiment/os6_names.sh` boots **two machines at the same time**,
joined by a QEMU socket netdev, which is a real L2 segment between
exactly two machines. It is the first time anything in this repository
needed more than one. The box is started, and the script waits not for
a guessed number of seconds but for the line the box itself prints:
the wire is ready exactly when the server says it is.

`machines/caisse_makeen.machine` declares no address, no resolver and
no printer. It is the till:

```
till: boot: network salle -- eth0 up 192.168.10.40/24 (dhcp), dns [192.168.10.1], names on makeen (/etc/resolv.conf)
till: ask imprimante.makeen -- 192.168.10.50 (from 192.168.10.1)
till: ask imprimante -- 192.168.10.50 (from 192.168.10.1)
till: ask makeen -- 192.168.10.1 (from 192.168.10.1)
till: ask fantome.makeen -- no such name on this network (from 192.168.10.1)
```

And the seat's own negative, in a third round: the SAME image, with a
hardware address nobody declared.

```
stranger: boot: network salle -- eth0 dhcp: no lease after 3 tries (no server answered on this network)
```

That line was not written for this seat. It is what the DHCP client has
said since NET-1 when nobody answers, and it is the truth about a
network that was never told about this device.

## The defect the first paired run exposed

The box **halted**. With no services declared, PID 1 reached `every
service has ended -- init has nothing left to keep alive` moments after
its verdict, and was gone before the till finished booting. The till
was correct to report that nobody answered.

The fix is not a flag. A machine that is its link's server of names has
not finished when its last one-shot has: every device on that network
asks it for an address at every boot and for a name whenever somebody
types one. A box that stopped the moment nobody was asking would be a
box that works until it is needed. PID 1 now says so and waits:

```
box: boot: every service has ended -- and this machine is still makeen: a server stops when the machine stops, not when the asking does
```

## Also paid for here

`zig build cross` caught a `Network` literal in `net.zig` missing its
new field — the third time that rule has earned itself, and the second
time on this exact file. The host build was green.

The Bash tool mangled `\n` inside a heredoc into a real newline twice,
producing a Zig string literal with a line break in it. The standing
workaround is the one that works: write the Python to the scratchpad
with the file tool and run it.

## The law this pays for

**A machine that serves a link is not finished when its services are.**
Serving is a state of the machine, not a task that completes.

---

# JRN-1 — the machine's own record: chained, signed, and never extended when it does not verify

The third act of 2026-09-14, and the one where the scope mattered more
than the mechanism.

## Whose record this is

RingServ described the target precisely, from a real constraint: French
anti-fraud law requires cash-register software to guarantee
inalterability, security, retention and archiving of sales records, and
its own shape log is "a sync convenience -- derived from tables,
deliberately trimmable, holding row images", which is "the opposite on
every axis" of what that law wants.

So the temptation was to build a business journal here. **This is not
one.** `JOURNAL` records what the MACHINE was and what it judged of
itself: one line per boot, carrying the digest of the declaration that
ran and the verdict PID 1 reached. What a record of business IS belongs
to the world that keeps it, and a floor that invented that would be
inventing its customer's domain.

The two compose exactly as MicroRing's identity design says: a device
signature attributes a record BEFORE it enters any ledger, and a chain
orders records WITHIN one. A world's journal of signed records sits
above this one; neither replaces the other.

## The record

Plain text, one entry per line, because a record a person cannot read is
a record nobody audits:

```
seq=1 prev=- machine=qemu_identity declaration=a48c59fbf8070f67 verdict=matched hash=<64 hex> sig=<128 hex>
```

`hash` is sha256 of everything before ` hash=`, and `sig` is Ed25519
over those same bytes -- the exact bytes on the line, not the object
they came from, which is MicroRing's rule and removes the class of bug
where two spellings of one record verify differently.

**No timestamp, deliberately.** The board has no clock of its own and
nothing on the boot path sets one, so a time in this file would be the
epoch wearing the authority of a date. The SEQUENCE is the order, and a
trusted clock is a named seam whose field can be appended to the payload
the day one exists.

## The rule that makes it worth keeping

**Verified before it is extended, and never extended when it does not
verify.** An entry appended after a broken one launders the break. A
machine that cannot keep its record has not booted as declared, so the
trial that would have committed is HELD -- the journal is not advisory.

And the claim is stated exactly: inalterability is not that a record
cannot be changed (any file can be changed) but that a change cannot go
UNNOTICED.

## Judged

The chain's logic is judged beside the code (`src/journal.zig`): three
entries verify; one word changed in entry two -- the verdict, which is
exactly the field someone would want to change -- is caught with its
position and its reason; a signature from another device is refused.

`qemu_identity` is now booted TWICE on the same disk, because a record
of one boot proves nothing about a chain (46 lines):

```
boot: start record -- pid N -- /stzos journal
journal /data/boot.journal -- no record yet: this is the first boot, and its entry is written after the verdict
boot: judge -- the boot matches its expectation (/etc/expected, 13 lines)
boot: journal -- /data/boot.journal: the chain begins, entry 1 signed by this device (verdict matched)
...
again: journal /data/boot.journal -- 1 entry, every one chained to the one before it and signed by this device
again: journal:   seq=1 prev=- machine=qemu_identity declaration=a48c59fbf8070f67 verdict=matched
again: boot: journal -- /data/boot.journal: 1 entry verified, entry 2 appended and signed (verdict matched)
```

`makeen_box` (121 lines) carries it across four card boots, and the
entry the UNMET trial wrote is the one worth reading:

```
unmet: boot: journal -- /data/boot.journal: the chain begins, entry 1 signed by this device (verdict differed)
```

The box wrote down that its boot was not the declared one. That is the
line an auditor wants and the line a vendor's box would never keep.

## The defect the repeated boots exposed

The final normaliser stripped everything before `boot: stzos init` on
EVERY line that matched, not only the first -- so the banner of a later
section (`steady:`, `again:`) lost its prefix, and several boots' first
lines read identically in one file. It went unnoticed while no machine
booted twice. Fixed to the first line only, which is the line the
firmware noise actually precedes.

## The law this pays for

**A record is the floor's or a world's, never both.** The machine says
what the machine did; what a business record is stays the business's.

---

# IDN-1 — a device is somebody: a key made once, kept where the power cannot take it, and a court that boots the same card twice

The second act of 2026-09-14. A box's name is a label; its KEY is who it
is. Until today every Makeen box in the world would have been the same
box to anyone reading a record it produced.

## The seat, and the design it borrows

`IDENTITY "<path>"` on a hosted MACHINE: where this device's own key
lives. PID 1 makes an Ed25519 pair there the first time the machine ever
boots, and loads it every time after. Fixture-first (A19, R64, R65, R66;
85/85 after, from 81/81).

The design is **MicroRing's**, read before a line was written, and two
of its findings are law here:

- **Ed25519 because of what it does not need.** Signing is deterministic
  (RFC 8032), so no nonce is drawn at signing time, and a board with no
  entropy source worth the name cannot leak its key by drawing a bad one.
- **The algorithm and the custody are SAID, never implied**, because the
  two are coupled: a key held in silicon may be a P-256 key, since some
  signing peripherals do not speak Ed25519. A record that assumed one
  algorithm would be the uniform pretence that design refuses. So the
  transcript says `ed25519, custody a file at /data/device.key`.

And the refusal that matters most is the one about WHERE:

```
R65: IDENTITY /tmp/device.key is where the key lives, and no declared
     MOUNT keeps it: a key on a filesystem that dies with the power is
     a new device every morning
```

R66 refuses the whole clause on the edge profile and says whose it is:
an edge device's key is MicroRing's, and its custody is the hardware's.

## The witness

`stzos attest`, as `stzos id` is the USER seat's and `stzos reach` is
EGRESS's. It signs with the device's key, verifies the signature against
the public half, and then **flips one bit in the message and shows the
same signature refused**. That second half is what makes the first half
evidence rather than a claim: a signature nobody tried to break proves
nothing.

## The claim is persistence, so the court boots the same card TWICE

A key that is made and used in one boot proves nothing about identity.
`experiment/os2_image.sh` now boots the card again after the trial has
committed, and that boot is where both of the first boot's decisions are
read back:

```
boot: identity -- ed25519, custody a file at /data/device.key -- created on this device, fingerprint KEY1
...
steady: boot: slot B -- committed, steady
steady: boot: identity -- ed25519, custody a file at /data/device.key -- already on this device, fingerprint KEY1
```

The held and unmet trials run on PRISTINE copies of the card and each
makes its own key (`KEY2`, `KEY3`) -- because a fresh card is a fresh
device, which is exactly what an identity should mean.
`makeen_box.expected` is now **117 lines** across four card boots.

## Normalising a value without hiding the claim

A fingerprint is the one thing a declaration cannot know: it is made on
the device from the device's own randomness, and a machine that could
derive it from its file would have no identity at all. So the derived
expectation ends in the wildcard, and the judge does NOT replace the
fingerprint with a constant -- that would erase the very claim. Each
DISTINCT fingerprint becomes `KEY1`, `KEY2`, … in order of first
appearance.

Measured: two consecutive builds, real fingerprints
`8038fb3d6c45b2de` and `b6a136f719a92fa3`, one pinned transcript. And a
key that CHANGED between two boots of one card would read as `KEY2` and
convict.

## What is NOT claimed

The private half never leaves because **no code in this repository sends
it**, and no world can read it because the file is the machine's own and
a world that declares a USER is not the machine. That is not the same as
hardware custody: a key in a secure element cannot be read by software
at all, and that is a different seat -- the edge profile's question
first, where MicroRing already named the coupling it costs.

## Judged

- `qemu_identity`: **18 lines**, new and pinned.
- `makeen_box`: **117 lines** (from 84), four card boots.
- `qemu_hello` 33, `qemu_egress` 19, `qemu_budget` 35, `makeen_qemu` 26:
  unchanged. A machine that declares no identity says nothing about one.
- 12/12 unit tests, 85/85 fixtures, the guarantees and the projection
  unchanged.

## The law this pays for

**A name a device cannot keep is not a name.** An identity that does not
survive the power is a new device every morning, and the declaration is
refused rather than believed.

---

# EGR-1 — a perimeter the declaration writes: how far a granted network reaches

The first act of 2026-09-14, and the one with a customer requirement in
a signed proposal behind it. DIKO's specification, requirement ESC6:
child-protection and gender-based-violence data must never leave the
organisation's perimeter. Until today the machine language could say
that a box speaks -- `CAPABILITY network` -- and not one word about
whom to.

## The seat

`EGRESS` on a NETWORK: a list of destinations, or the word `none`.

```
DEFINE NETWORK lan AS (
  INTERFACE "eth0",
  ADDRESS "10.0.2.15/24",
  GATEWAY "10.0.2.2",
  EGRESS ["10.9.0.0/16"]
) RATIONALE "The programme's own range, reached through the gateway, and nowhere else"
```

Fixture-first, the court red for four named reasons before the parser
was touched (A18, R60, R61, R62, R63; 81/81 after, from 76/76). The
sharpest refusal is R60: **a gateway is a way out, and `EGRESS none`
says there is none** -- declare one or the other.

## What it does, exactly

It writes the ROUTING TABLE from the declaration. With a declared reach,
one route per destination is installed and **no default route at all**;
with `none`, no route is added and the box knows no way off its own
link; saying nothing is what every machine did before this seat, where a
declared GATEWAY becomes a default route.

## What it is NOT, said as plainly

**This is the routing table, not a packet filter.** The guarantee is
*the machine knows no way there*, not *the machine is prevented from
finding one*. A world with the privilege to add a route could add one --
there is no shell on the boot path to do it with, and a world that runs
as a declared USER has no such privilege, but the distinction is real
and the claim stops where it stops. A netfilter seat over netlink would
be the stronger statement; it is named here and not built.

Stated that way, it is still the answer a clause in a contract cannot
give: a box that cannot route to the open internet does not have to be
TRUSTED to refrain.

## Judged by the kernel's own answer

`machines/qemu_egress.machine`, the sixth pinned transcript, 19 lines:

```
boot: network lan -- eth0 up 10.0.2.15/24
boot: egress lan -- 10.9.0.0/16 and nowhere else: no default route
boot: start allowed -- pid N -- /stzos reach 10.9.0.1
reach 10.9.0.1 -- a route exists: this machine knows a way there
boot: start denied -- pid N -- /stzos reach 8.8.8.8
reach 8.8.8.8 -- no route: this machine knows no way there
```

Note the network line: no `gateway` clause, because with a declared
reach no default route was installed -- the line says what happened,
and the egress line says the reach.

`stzos reach <a.b.c.d>` is the witness, as `stzos id` was the USER
seat's: it asks the KERNEL and says what it answered. A UDP `connect()`
is the whole question -- it performs the route lookup and sends nothing
-- so a machine with no way to an address learns that **without a single
packet leaving it**, which is the point when the address is one the
perimeter forbids.

## What the cross build caught, again

The host build was green and `zig build cross` was not: two errors in
code only Linux compiles -- a Network literal in the by-hand `stzos net`
verb missing the new field, and a double pointer where the new line is
printed. The rule in `CLAUDE.md` earned itself again: a Windows build
proves nothing about the init.

## Judged

- `qemu_egress`: **19 lines**, new and pinned.
- `makeen_box` **84** and `makeen_qemu` **26**: unchanged. They declare
  no reach, so they say nothing about one -- a machine written before
  this seat has the transcript it always had.
- 12/12 unit tests, 81/81 fixtures.

## The law this pays for

**A capability says what kind of effect a machine may have; only a
declaration of reach says how far.** Granting the network and leaving
the destination to whatever the box happens to find is how data leaves a
perimeter nobody wrote down.

---

# OS-5-PREP — the board's first boot, written and rehearsed before the board exists

Last of the five acts of 2026-09-13. OS-5 itself is NOT done: no card
has been flashed and no board has booted. What is done is everything
that can be done without one, so that the first real boot is a command
rather than an improvisation — and so that whatever it says is judged by
instruments that were written while nobody knew what it would say.

## `experiment/os5_board.sh`, four acts

**`card`** — what to flash and what it is. The digests of the machine
file, the card, the kernel and the initramfs; the boot the BOARD expects
of itself, printed in full; the two lines the emulator could not keep;
then the wiring (GPIO 14 and 15 with a ground, 3.3 V, 115200 — the
mini-UART the machine declares as `CONSOLE /dev/ttyS1`).

And one check worth the whole act: **the card's own boot line carries no
instrument of the court.** Every instrument is the emulator's — the
watchdog turned off, the lens chosen, the boot halted at the verdict —
and a card that carried one would be a box that behaves like a court,
which is the one thing a box on a counter must never do. The script
reads `cmdline.A.txt` and `cmdline.B.txt` and refuses to go on if it
finds `stzos.watchdog=off`, `stzos.expect=`, `--halt-on-verdict` or
`--hold`. Today they are clean:

```
  cmdline.A.txt: console=ttyS1,115200 quiet loglevel=3 stzos.slot=A rdinit=/stzos -- init /etc/machine
  clean: the card boots the box, not the court
```

**It never writes to a device.** Flashing is the one act here that can
destroy a computer if a letter is wrong, so the script prints the
command and the author runs it. The Windows tools are named first
because they refuse a system disk.

**`listen <dev> [seconds]`** — the console, captured to a file at
115200 8N1, with the `usbipd attach` line WSL needs before a USB serial
adapter exists inside it at all.

**`judge <file>`** — three judges on one captured boot:

1. **the board's own verdict**, which PID 1 printed on that console: the
   machine judging its own boot against the `/etc/expected` it carries
   (JDG-1);
2. **the court's verdict**, the same judge run from the host over the
   captured text — `stzos judge <machine> <transcript>`, new here. Two
   independent witnesses to one boot, which is the reason to keep both;
3. **the four standing promises** (GRT-1), which on a board should for
   the first time be kept all four by ONE text.

Then it names what a board is expected to say that the emulator could
not, and what only a board can show: the watchdog's real countdown, and
the tryboot flag that still needs a vendored patch to `bcm2835_wdt.c`.

**`rehearse`** — the same three judges against the emulator's pinned
transcript, with no hardware at all. That is how this script was proven
today:

```
--- 1. the BOARD's own verdict (what PID 1 said about its own boot)
    the boot matches its expectation (/etc/expected.emulator, 17 lines)
--- 2. the COURT's verdict (the same judge, run from the host)
    judge makeen_box -- the boot this machine EXPECTS (emulator lens, 17 lines)
      every expected line was said
```

## `stzos judge` — the host's own reading

The machine judges its LEDGER as it boots; this judges the TEXT a serial
cable carried away. A captured transcript is not a ledger: it carries
the kernel's lines, the worlds' output and the console-only lines PID 1
says about the card. So the comparison is one-sided on purpose — every
expected line must have been said, and everything else the machine said
is printed rather than judged, because a real boot legitimately says
more than its expectation.

It reuses the derivation and the comparison the machine itself uses
(`src/expect.zig`), so the two witnesses cannot drift: one wording, two
readers.

## What waits on the author

`STZ-OS-HARDWARE-01`: a Raspberry Pi 4 Model B, a micro-SD card, and a
3.3 V USB-serial adapter. Nothing else. The card image is built, its
digests are printed, the wiring is written down, and the judges are
rehearsed.

---

# GRT-1 — the guarantee sheet becomes a verdict: four promises, judged by name against the machine's own evidence

Fourth of the five acts of 2026-09-13. `GROUND.md` had written the item
itself: *RestoLean's four guarantees should be four named expectations
judged by the court, so that "always reachable, stable name, durable
log, survives the cut" is a verdict, not a brochure.*

## Whose promises these are

A restaurant's, first. RestoLean's Makeen thread called MakeenOS "a
posture, never a marriage": a sheet of guarantees that imposes itself
over whatever host is underneath, written by Amor in four words each --
*toujours joignable, nom stable, journal local durable, traverse la
coupure*.

They are not one customer's, which is why `stzos guarantees` carries
them as the HOSTED PROFILE's four standing promises. A box behind a
counter, an NGO's hub in Diffa, a bank's server and a school's machine
make the same four or say they make none. `qemu_hello` says it makes
none, and that is a verdict too: **0 of 4 promised**.

## What the verb does

`stzos guarantees <file.machine> <text>` reads the DECLARATION for what
is promised and a TEXT for what is kept, and says one of three things
per promise: not promised, KEPT (with the line that keeps it, quoted),
NOT KEPT (with what was looked for and not found). Nothing restates the
declaration as its own evidence -- a promise is kept only if a line of
the text says so.

Two promises are also ORDERING claims, and the judge checks the order:
the wire and the partition must be up BEFORE the first world starts,
because a world that starts on a floor which is not ready has already
been told a lie.

## Judged twice, because two texts are needed today

`experiment/judge_guarantees.sh` runs it against both, and the pinned
verdict (`machines/makeen_box.guarantees.expected`, 39 lines) holds both
reports:

- **the board's expectation** (`zig-out/image/makeen_box/expected`,
  derived through the board's lens): **3 kept** -- the wire up at its
  declared address before any world, the address declared and not
  leased, the partition mounted before any world spoke. The fourth is
  NOT KEPT for a reason the judge states precisely: *this text carries
  no slot decision -- an expectation stops where the verdict begins*.
- **the court's transcript** (`machines/makeen_box.expected`, what the
  emulator really printed): **1 kept** -- the durable log. The other
  three name the emulator's own lacks: `the wire never came up -- boot:
  network lan -- eth0: no such interface (NODEV)`, `no line carries
  192.168.10.1/24`, and the watchdog line that says a trial cannot roll
  back by hardware there.

Neither text can keep all four, and the pair says exactly why. That is
the honest state of the box until OS-5 puts a card in a board: on that
day ONE transcript keeps all four, and this verb is what will say so.

## The mechanism, asserted before its scoreboard

Two mutations, each in a fresh run:

- the mount line removed from the expectation → *a durable log: NOT
  KEPT -- no line says 'mount ext4 at /data -- done'*;
- the wire's line moved AFTER the first start → *always reachable: NOT
  KEPT -- the wire came up AFTER a world had started*.

## The defect the first run found, in the judge itself

The first version searched the whole text for a substring and reported
**a stable name: KEPT** — citing the line
`unmet: boot: judge -- expected, not said: network lan -- eth0 up
192.168.10.1/24`. A promise judged kept by the very line saying it was
missing.

A transcript carries more than one boot: the court runs the same card
again held and again through another lens, prefixing those (`hold: `,
`unmet: `), and PID 1 QUOTES lines it expected and did not say. Both
answer a substring search; neither is evidence about this boot. So
evidence is now what PID 1 said about THIS boot: a line that begins
`boot: ` and is not the judge quoting.

## The law this pays for

**Evidence is what the machine said about this boot, never what it
quoted about another.** A judge that searches a whole text will find the
words it wants inside the sentence that denies them.

---

# BDG-1 — a budget the KERNEL holds: the wall between one world and the next, and the gate that made the transcript a fact

Third of the five acts of 2026-09-13. The dividend document promised a
wall between an inference world and the kitchen display; this is that
wall, built while the only thing on the other side of it is a stand-in
that allocates.

## The seat

`MEMORY <mebibytes>` and `CPU <percent of one core>` on a service.
Fixture-first as always (A17, R56, R57, R58, R59; the court red for
four named reasons before the parser was touched; 76/76 after, from
71/71).

```
DEFINE SERVICE greedy AS (
  RUN ["/stzr", "/app/greedy.luau"],
  RESTART on_failure,
  READY "/run/greedy.ready",
  MEMORY 32,
  AFTER [modest],
  NEEDS [process, filesystem]
) RATIONALE "..."
```

## The mechanism, which cost this repository nothing

cgroup v2 is a filesystem: a group is a directory, and a ceiling is a
line of text written into it. So a budget needs no daemon, no agent and
no library. PID 1 stays in the root group (exempt from the
no-internal-process rule), delegates `+memory +cpu` to its children,
makes one directory per budgeted world, writes `memory.max` and
`cpu.max`, and moves each world into its own group between the fork and
the exec -- so a world is never outside its ceiling for an instant.

A machine that declares no budget mounts no cgroup filesystem and asks
for no controller: the plan shows the mount only when a world asks for
one, and the kernel fragment gains its five options only then.

**The two ceilings do different things, and the difference is the
point.** Memory KILLS -- SIGKILL, inside the world's own group, with the
neighbour untouched. CPU THROTTLES -- the world waits for its next
slice and nothing dies, so a held cpu ceiling appears in no transcript
at all.

## Judged by a world the kernel kills

`machines/qemu_budget.machine`, the fourth pinned transcript: `modest`
holds 8 MiB of its 64 and ends; `greedy` asks for far more than its 32
and is killed by signal 9, five times, each restart the declared policy
and each kill the kernel's:

```
boot: budget -- modest 64 MiB and 50% of a core, greedy 32 MiB; the kernel holds the ceiling, not the world
boot: start greedy -- pid N -- /stzr /app/greedy.luau
greedy: this world was granted 32 MiB, and is about to ask for far more
boot: greedy (pid N) killed by signal 9
boot: restart greedy (on_failure, 1/5) -- pid N
...
boot: greedy -- restart on_failure, but gave up after 5 restarts
boot: every service has ended -- init has nothing left to keep alive
```

35 lines. The world's own file carries a bound of 512 MiB that the
kernel should never let it reach: if the ceiling did NOT hold, the
transcript would say so in one line instead of hanging. The machine
never reaches a verdict on its own boot, which is the truth about a
boot where a world never served.

## The gate: what this act found in the old code

Adding the budget changed the timing of the smallest machine, and its
pinned transcript FLIPPED two lines:

```
-boot: start whoami -- pid N -- /stzos id -- as world (1000:1000)
 id: uid=1000 gid=1000
+boot: start whoami -- pid N -- /stzos id -- as world (1000:1000)
```

PID 1 could only print a start line AFTER the fork, because the line
carries the pid -- and `stzos id` is a static binary that prints one
line and exits, so it beat its own start line to the console. The race
had always been there; every earlier transcript had simply won it.

**The fix is a gate, not a wider normalisation.** Between the fork and
the exec the child now blocks on a pipe, so PID 1 can put it in its
cgroup and SAY that it started before the world says anything. One
spawn path serves both a world with a declared USER and one without,
the credential drop happens at the same moment it always did, and the
order of every transcript became a fact rather than a margin. The
proof: `qemu_hello` matched its ORIGINAL pin again, unchanged, 33
lines.

## Judged

- `qemu_budget`: **35 lines**, new and pinned.
- `qemu_hello` **33**, `makeen_qemu` **26**, `makeen_box` **84**: all
  matched their existing pins after the gate, none re-pinned.
- 12/12 unit tests, 76/76 fixtures, the projection and its consumer
  unchanged, the WSL rehearsal still catching its stale world.

## The law this pays for

**A transcript whose order depends on which process reaches the console
first is a margin, not a fixture.** Where PID 1 must speak before a
world does, it holds the world until it has spoken.

---

# HLT-1 — the watchdog is fed on HEALTH: a world can be alive and wedged, and until today nothing noticed

Second of the five acts of 2026-09-13, and the second half of the
guarantee RestoLean's sheet calls *traverse la coupure* — survives the
cut. SRV-1 gave the box worlds that serve. This one asks what happens
when a world is still there and no longer serving.

## What was wrong

The hardware watchdog was fed every turn of PID 1's loop, unconditionally.
So it protected the box against exactly one thing: PID 1 itself dying,
or the kernel hanging. A kitchen display whose process is alive and whose
service has stopped — the ordinary failure of a real box — fed the
watchdog just as happily as a healthy one, and an A/B trial committed on
a world that had served for an instant.

## The seat

`HEALTH <seconds>` on a service that declares READY: the window within
which the daemon must REFRESH that path. Fixture-first, as always — the
court went red for three named reasons before a line of the parser was
written (A16, R53, R54, R55; 71/71 after, from 67/67).

```
DEFINE SERVICE kds AS (
  RUN ["/stzr", "/app/kds.luau"],
  RESTART always,
  READY "/run/kds.ready",
  HEALTH 5,
  NEEDS [network, filesystem]
) RATIONALE "..."
```

One path, two roles, and R45 still holds: one path signals for one
service. The world creates it to say *I am serving*, and touches it to
say *I am serving still*.

## What it changes, in three rules

1. **The feed.** PID 1 feeds the hardware only while every world with a
   window is fresh. The first that goes stale is named — `kds -- stale:
   /run/kds.ready has not been refreshed for 6s (window 5s)` — the feed
   stops, and the board's reset into the committed slot is the answer.
2. **The commit.** A trial commits only once every such world has been
   ready THROUGH one full window. "Serving" measured at the instant of
   the signal is not worth an update; "serving one window later" is. The
   commit line says so in the transcript.
3. **The latch.** Staleness does not clear. A world that recovers does
   not resume the feed, because a feed that resumed would hide exactly
   the fault the watchdog exists for. AFTER is untouched: readiness is
   still the signal, so nothing waits a window to start.

A world that deletes its own signal is stale too — the check reads the
path's mtime, and a missing path is not a fresh one.

## The negative, demonstrated

`machines/wsl_rehearsal.machine`'s `signals` service is
`flock /tmp/stzos-signals.ready /bin/sleep 30`: it CREATES its path at
start and never touches it again. That is precisely the world HEALTH
exists to catch, and it was already in the rehearsal for another reason.
With `HEALTH 2` declared it is caught in seconds, with no kernel and no
emulator:

```
boot: signals -- stale: /tmp/stzos-signals.ready has not been refreshed for 2s (window 2s)
boot: this machine declares no SLOTS and arms no watchdog; on a board a stale world is what resets it
```

The rehearsal's `--turns` went from 8 to 12 for one reason, stated in
the script: the run has to OUTLIVE a window, or it proves nothing.

## The positive, pinned

The box's worlds refresh every second against a five-second window. The
card's three boots are unchanged in kind and now carry the rule:

```
boot: health -- kds every 5s, poste every 5s; a world that stops refreshing stops the watchdog
boot: slot B -- committed: every service is ready and has held its health window and the boot matches its expectation
```

- `makeen_box`: **84 lines** (from 81), three card boots.
- `makeen_qemu`: **26 lines** (from 25).
- `qemu_hello`: **33 lines, untouched** — one-shots declare no window.
- The two lenses still differ on exactly the emulator's two lacks.
- 12/12 unit tests (the window's own logic is judged beside the code:
  ready at the signal, proven one window later, the latch, and a world
  with no window owing nothing), 71/71 fixtures.

## The law this pays for

**Alive is not serving, and a watchdog fed by the fact that a process
exists guards nothing that matters.** The declaration now carries the
difference, and the hardware answers to it.

---

# SRV-1 — the box's worlds SERVE: a daemon never exits, and an init that waits for an exit learns nothing more

First of the five acts the author ordered on 2026-09-13, and the one
everything else stands on: until today the Makeen box's two worlds were
stand-ins that printed two lines and exited, so every box transcript was
a lie of shape. A kitchen display serves a service; it does not end.

## The declaration first

`machines/makeen_box.machine` and `machines/makeen_qemu.machine` now say
what the worlds are:

```
DEFINE SERVICE kds AS (
  RUN ["/stzr", "/app/kds.luau"],
  RESTART always,
  READY "/run/kds.ready",
  NEEDS [network, filesystem]
) RATIONALE "The kitchen display world: a daemon that serves the kitchen and says so by creating its READY path; PID 1 keeps it alive for the life of the box"
```

The grammar needed nothing new: RESTART and READY were seated at RDY-1.
Fixture A2 is `makeen_box.machine` verbatim, so it was RE-TAKEN from the
file mechanically rather than hand-copied, and `fixtures.json` re-pinned
in this commit (67/67, unchanged: the widening was a machine's, not the
language's).

## The runtime owed them one primitive

A daemon has to YIELD. Luau's sandbox ships no timer, so stzr gained a
fourth granted capability beside `readfile` and `writefile`:
`sleep(ms)` (`stz/src/main.zig`, judged by `stz/experiment/run_sleep.luau`,
6/6). The alternative was a busy loop, and a busy loop lies twice: it
reports "serving" while it spins a core, and under TCG emulation it
spends the boot's own time. A negative argument is refused rather than
rounded to zero — silence about a wrong argument is how a daemon becomes
a one-shot nobody noticed. The suite was probed with the wait removed
(`sleep(0)` where `sleep(120)` stood): red for its named reason, exit 1.

## The defect a daemon found, which no one-shot could

The first boot with a serving world stopped dead after the kitchen
display signalled. `poste` never started; the court's timeout was the
only thing that noticed.

**PID 1 was blocking on `wait4` for a child that never exits.** Two
bugs, one cause — the loop assumed every change arrives as an EXIT:

1. `startReady` was called only when a signal was still OUTSTANDING
   (`if (awaiting)`), never when one had just APPEARED. The moment the
   display's path showed up, nothing was awaiting any more, so the world
   that came AFTER it was never started.
2. With no service awaiting and no slots, the loop chose a BLOCKING
   `wait4`. A daemon never exits, so that call never returns.

`pollReady` now reports both facts the loop needs — a signal APPEARED
(start what waited on it) and a signal is OUTSTANDING (keep polling) —
and the loop polls while any of four things is true: the watchdog needs
feeding, a signal is outstanding, a service has not started yet (only a
signal can start it), or the court's instrument is still owed a verdict.

## The instrument: a served boot still has to close

A real init keeps a served machine alive for years. A transcript that
never closes is not a fixture, so `stzos init --halt-on-verdict` halts
the moment every service is ready AND the boot is judged. It is DERIVED
from the declaration — any service that is not a one-shot — onto the
EMULATOR's boot line only; the card's `cmdline.txt` never carries it,
because a board must keep the box alive. No verdict is no halt: a daemon
that never signals leaves the court's timeout to convict it, which is
"no expectation is no commit" seen from the other side.

## The ordering trap, found in the same run

The worlds wrote their READY path and THEN printed "serving". PID 1
polls every 250 ms, so its `ready` line could land between the two — a
transcript whose order depends on a poll is not a fixture. The signal is
now the LAST act of a world, after everything it has to say. And PID 1
flushes its own lines when a signal is seen: a served machine never
reaches the reaper's flush, because no child exits, so without it PID 1's
lines arrived in a batch at the end.

## Judged

- `makeen_qemu`: **25 lines** (from 23). Both worlds serve, signal, and
  are seen; `judge -- matches (/etc/expected, 15 lines)`; the boot ends
  on the instrument.
- `makeen_box`: **81 lines** (from 75), three card boots unchanged in
  kind — the trial commits and the card boots B, the held trial does not
  and the card boots A, the trial judged through the BOARD's lens names
  the emulator's two lacks, holds itself, and the card still boots A.
- `qemu_hello`: **33 lines, untouched** — every service is a one-shot,
  so no instrument is derived onto its line. It stays the control case.
- The WSL rehearsal, the projection and its consumer, the stzu
  meta-court: unchanged. 11/11 unit tests, 67/67 fixtures.

## The law this pays for

**A daemon never exits, so an init that waits for an exit learns nothing
more.** Every loop that watches a machine must ask what happens when
nothing ends — and the answer must be in the transcript, not in a
timeout. The one-shot machine hid this for a day and a half; the first
world that served found it in one boot.

---

# JDG-1 — the machine judges its own boot: the expectation rides in the image, a trial commits only on a match

The author said: close the loop. The loop was this: every boot was
judged from OUTSIDE — QEMU's serial transcript, normalised and diffed
by a script against `machines/<name>.expected` — while the machine
itself committed an A/B trial on "every service is ready" and nothing
else. The Makeen box's emulated trial committed with its network
refused NODEV, and the court was green, because the court judged the
transcript and the machine judged nothing.

## What closes it

`stzos image` now DERIVES the init lines a faithful boot prints — from
the plan, through a LENS — and the initramfs carries them as
`/etc/expected`. PID 1 records every judged line it says (a ledger:
written first, then echoed to the console, so the two cannot disagree)
and, the moment every service is ready, judges the ledger against the
expectation in its own words:

```
boot: judge -- the boot matches its expectation (/etc/expected.emulator, 16 lines)
boot: slot B -- committed: every service is ready and the boot matches its expectation; config.txt now boots B, A is the fallback
```

The rule for a trial changed from "ready" to "ready AND matches". A
boot that differs names the lines and holds itself:

```
boot: judge -- the boot differs from its expectation (/etc/expected): 2 line(s) expected and not said, 2 said and not expected
boot: judge -- expected, not said: network lan -- eth0 up 192.168.10.1/24
boot: judge -- expected, not said: watchdog armed (/dev/watchdog)
boot: judge -- said, not expected: network lan -- eth0: no such interface (NODEV)
boot: judge -- said, not expected: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here
boot: slot B -- held: every service is ready but the boot is not the one expected; not committed, the watchdog is no longer fed -- the next boot is A
```

No expectation is no verdict, and nothing to judge by is nothing to
commit on: text before act, applied to the act itself.

## The lens

The emulator lacks what the board has — no GENET, and a watchdog it
resets on — so one expectation cannot be true of both. The image
derives two: `/etc/expected` (the board's) and `/etc/expected.emulator`
(the emulator's), from one plan and a `Lens` with one field per lack.
The emulator's boot line says `stzos.expect=emulator`, beside the
`stzos.watchdog=off` it already said; the card's `cmdline.txt` never
does. **The diff of the two texts IS the list of the emulator's lacks**,
printed at build time:

```
--- the emulator's lacks (expected vs expected.emulator):
  the board:  boot: network lan -- eth0 up 192.168.10.1/24
  the board:  boot: watchdog armed (/dev/watchdog)
  the emulator:  boot: network lan -- eth0: no such interface (NODEV)
  the emulator:  boot: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here
```

The sentence this repository has repeated since OS-4 — "the board is
expected to differ exactly where the emulator lacks the hardware and
nowhere else" — is now a derived text, and the board's first boot
(OS-5) will be judged against `/etc/expected` by the board itself.

## Two rules, no diff, no timer

The pids the kernel hands out are normalised to `N`; `pid 1` stays
literal, because that init IS PID 1 is a claim the judge must be able
to convict (the script's judge keeps it for the same reason). A line
the declaration cannot fully know — a dhcp lease — ends in `*` and
matches by prefix: `network lan -- eth0 up *` met `10.0.2.15/24,
gateway 10.0.2.2 (dhcp), dns [10.0.2.3]` on `virt`. Nothing else is
loose. The lines are compared as a SET: AFTER already enforces the
order that matters, and two daemons signalling ready in either order
are the same boot. Count is judged: a line said twice is a restart, and
a restart before readiness is not the boot that was declared.

Every judged line is worded ONCE, in `src/expect.zig`: init prints
with those format strings and `derive()` writes the same. A line worded
twice would drift, and a drift is exactly the false alarm a
self-judging machine must never raise. The wording is still pinned from
outside by the three transcripts, so a drift would be convicted twice.

## What is judged, and what is not

The ledger holds what init said about the MACHINE: the banner, the
console, the slots, every mount's result, every capability, every
network's result, the watchdog, every start, every exit and signal
before readiness. It does not hold what the CARD says (a trial, or
steady — the declaration cannot know which boot this is), the
instrument's lines (`--hold`), or the verdict itself. What comes after
readiness — the exits of daemons, the halt — is the court's to judge,
not the machine's.

## Judged, three machines and three card boots

- `qemu_hello`: `judge -- the boot matches its expectation
  (/etc/expected, 14 lines)`; pinned at 33 (from 32).
- `makeen_qemu`: matches, 15 lines, the lease through the wildcard;
  pinned at 23 (from 22).
- `makeen_box`, three boots on `raspi4b`: the trial through the
  emulator's lens matches (16 lines) and commits, the card boots B; the
  same trial held by the instrument matches and is held, the card still
  boots A; and the NEGATIVE, new: the same trial judged through the
  BOARD's lens (`boot_unmet.cmd`, the emulator's line without its lens)
  differs on exactly the two lacks, holds itself, the card still boots
  A. Pinned at 75 (from 49).
- the WSL rehearsal and namespace transcripts: unchanged. Neither
  reaches readiness (`mute` never signals), so neither is judged; a
  rehearsal is never judged by design.
- `src/expect.zig`: five unit tests — the board's derivation pinned
  line for line for a machine with a static network, a gateway, dns, a
  USER, a one-shot and a READY daemon; the two lenses differing on
  exactly two lines; a match across pids and readiness order; a line
  missing, a line unexpected, a line said twice; the wildcard and the
  literal `pid 1`. 11/11 with the rest.

## The law this pays for

A machine that cannot tell its own boot from another cannot be trusted
to commit an update. Now it can: the same text the author reads on the
console, the agent reads in the pinned transcript, and the machine
reads from its own image. Text before act reached the act.

---

# PRJ-2 — the consumer convicts what the diff could not: Ring's comment is '#'

The author said: run the projected `device.ring` through MicroRing. It
was refused on the first try, and the refusal is the point of this
entry.

```
Error (S1) In file: eval
In Line (11) Literal not closed
```

**Line 11 of the projection was a COMMENT** — and Ring's comment
character is `#`, not `--`. `--` is the machine language's, which is
Lua's, and I had carried it across without checking MicroRing's own
files (its template and every example open with `#`). Ring therefore
saw no comment at all, read the prose as code, and the apostrophe in
"the Device language's" opened a string literal that never closed.

**The judge could not have caught it.** `judge_project.sh` diffed the
projection against an expectation taken from the same generator: both
sides were wrong in the same way, and the court was green. Only the
CONSUMER could convict, and it did, in one line, the first time it was
asked. So the consumer is now part of the judge: after the diff,
`judge_project.sh` runs MicroRing on the projection when a binary is
found beside the repository, and says so when there is none.

With `#`, MicroRing accepts and runs the projected file unchanged:

```
[microring] pico2 . 2 pin(s) . 2000ms
[microring] done at 2000ms
```

Two pins and the declared board, read out of a file this repository
wrote from a `.machine` declaration. The expectation is re-pinned in
the same commit as the fix.

**The law this pays for:** a generated artifact is judged by the thing
that consumes it, not by a diff against yesterday's output of the same
generator. The transcripts have always had that property — QEMU is a
real consumer — and the projection did not until now.

---

# PRJ-1 — the edge profile projected: a MicroRing project, written and judged

Fourth and last of the four the author ordered on 2026-09-12, and the
only one that reaches into another repository's territory — so it was
read first: MicroRing's own templates, `Device()` seam and examples say
exactly what it consumes, and nothing here was invented.

## What MicroRing is owed, and what it owns

A MicroRing project IS a folder with a `device.ring` in it (its CLI
says so by refusing anything else), and that file holds one
`Device([...])` declaration: `:board`, `:pins` (each `[:gpio, :mode]`),
and the behaviour — `:every`, `:on`, `:parts`. The first two are
exactly what a `.machine` file declares. The behaviour is not, and this
repository does not invent it: it belongs to the **Device language**,
an L2 member of the alphabet, and until that exists the every/on
handlers are the author's own Ring code beside the generated file.

MicroRing's standing refusals are untouched: not an RTOS, not a new
language, the firmware and the tiers are its own. `stzos project`
writes text and hands it over.

## What was built

- **The edge boards, fixture-first** (A15, R51, R52; A3 re-pinned as
  `machines/cold_room_sensor.machine` verbatim; **67/67**): each
  profile has its own board menu and its own emulator board — hosted
  keeps `qemu_pc`/`qemu_virt`/`rpi4`, edge gets MicroRing's own words,
  `sim` (its simulator, and the edge default), `pico2`/`pico2w` (tier
  2, its flagship) and `esp32c6` (tier 3). A board of the other
  profile is refused BY PROFILE, which is what R35 always meant; the
  earlier reading ("an edge machine names its board in its own
  substrate") was written before MicroRing had been read and is
  corrected here. `thumbv8m` joins the architectures, because the
  RP2350 is a Cortex-M33 and the fixture should not lie about it.
- **`stzos project <file.machine> --out <dir>`** (`src/project.zig`):
  the `device.ring`, and a printed account of what did NOT cross over —
  the flash MOUNT (the substrate mounts it), the capabilities (the
  machine's envelope, which MicroRing has no gate for), each service's
  behaviour (the Device language's). The generated file carries the
  same account in its own comments, so it is legible where it lands.
- **Both refusals**: `stzos project` refuses a hosted machine, and
  `stzos image` refuses an edge one, each naming the other verb.

## What was measured

`machines/cold_room_sensor.device.ring.expected`, 20 lines, identical
under `experiment/judge_project.sh`. The projected file is real
MicroRing source: `Device([ :board = "pico2", :pins = [ :led = [ :gpio
= 25, :mode = :out ], :probe = [ :gpio = 4, :mode = :in ] ] ])`.

## Named seams

- The Device LANGUAGE itself (behaviour: every/on/parts as declared
  sentences rather than Ring code) — an L2 member, not this
  repository's to declare.
- `:parts` (a sensor's type, an ADC channel) has no seat in the machine
  language yet; a PART kind is a fixture-first widening when a real
  sensor needs it.
- Running the projection through MicroRing itself (`microring run`) on
  this host: MicroRing's desktop runtime is built and closed, so this
  is a real next step rather than a wish.

---

# USR-1 — a declared identity: a service stops being the machine

Third of the four the author ordered on 2026-09-12. Until now every
service ran as the machine itself, which is to say as root: a world
that only draws a kitchen display could rewrite the boot partition.

## What was decided

**An identity is declared, not looked up.** `DEFINE USER kds AS (UID
1000, GID 1000)` is a kind of its own, and a service names it with
`USER kds` — a reference resolved at check time like AFTER, so a
service running as a nonexistent identity is refused before any boot.
**uid 0 cannot be declared** (R47): root is the machine itself, so a
service that needs the machine's own powers is visibly the one with NO
user line, rather than one that asked for root. **GID defaults to the
UID**, the convention a small machine wants and one fewer number to
keep in step. **The image derives `/etc/passwd` and `/etc/group`** from
exactly the declared set plus root, with `/nonexistent` for every
shell, because a machine that has no shell should say so in its own
files.

## What was built

- The USER kind and the SERVICE seat, fixture-first (A14, R46–R50;
  **64/64 on the first run**), `machine.stzu` gaining the declaration
  (7 declarations now, accepted by stz's meta-court), the plan printing
  `-- as world (1000:1000)`.
- **PID 1 drops the credentials between fork and exec** (`src/init.zig`):
  `std.process.Child` has no seat for a uid, and the drop must happen
  in the one moment when the child is still ours and not yet the
  program's. So a service with an identity is forked by hand, does
  `setgid` then `setuid` — group first, because after `setuid` there is
  no privilege left to change the group with — and execs. A failure
  between fork and exec exits 126 or 127 rather than returning into
  init's loop with a second init in it.
- **`stzos id`**, the witness: a machine has no coreutils, so the one
  binary answers `uid=N gid=N` from inside it.

## What was measured

`machines/qemu_hello.machine` declares `USER world` and a service that
runs `stzos id` as it. The boot says both halves: `start whoami -- pid
N -- /stzos id -- as world (1000:1000)` from PID 1, and `id: uid=1000
gid=1000` from the service. Pinned at **32 lines**, up from 28, in the
same commit as the seat. The other two machines and the rehearsal are
unchanged and judged identical.

## Named seams

- Supplementary groups, and a service's umask.
- The per-DEVICE identity (an Ed25519 key that never leaves the board)
  is a different thing from a per-service uid and is still queued.
- File ownership in the image: everything is still owned by root, so an
  identity can read what it is given and write only where the machine
  made a writable place (`/tmp`, a declared mount).

---

# ZIGCC-1 — the kernel built by our own compiler: four walls named, the tree builds, the image does not boot

Second of the four the author ordered on 2026-09-12. The architecture
table has said since OS-2 that `make CC="zig cc"` is the destination
and gcc was the stand-in. This measures it. **The answer is no, not
with zig 0.15.2** — and the four walls are named, two of them zig
defects worth reporting upstream.

## What was decided

A Linux zig is needed: the Windows one cross-compiles stzos but cannot
drive `make` inside WSL. It is fetched ONCE and **pinned by digest**
(`experiment/zigcc_fetch.sh`, `vendor/zig/PIN.txt`, sha256 from
ziglang.org's own index), exactly as the kernel tarball and the board
firmware are. The experiment lives behind `STZOS_CC=zigcc` on
`os2_image.sh`, in its OWN kernel tree per architecture, so the two
toolchains never share an object and the default stays gcc.

## The four walls, in the order they appeared

1. **`-mtune=generic` stops the first object.** zig cc parses
   `-march`/`-mcpu`/`-mtune` itself, into zig's own CPU model, and
   knows no CPU named "generic". Dropped in the wrapper: a scheduling
   hint, never a meaning.
2. **Unused arguments are errors.** zig cc makes
   `-Wunused-command-line-argument` an error and the kernel's assembly
   rule passes flags that phase does not consume.
   `-Wno-unused-command-line-argument` added.
3. **Assembly plus a dependency file produces NOTHING, and exits 0.**
   Asked for `-S` together with a depfile in either spelling
   (`-Wp,-MMD,P` or `-MMD -MF P`), zig cc writes the depfile, writes no
   assembly, and reports success; the kernel then stops at "cannot open
   devicetable-offsets.s". Isolated flag by flag on the kernel's own
   failing command (`zigcc_probe3.sh`). **A zig defect**, and the
   nastiest kind: silence with a zero exit. The wrapper splits it into
   two truthful passes — the assembly alone, then the preprocessor
   alone for the dependencies — and the depfile still lists every one
   of the hundred headers the source includes. Nothing forged.
4. **PIC is decided by the target and cannot be argued with.** Under
   PIC a symbol's address is not an immediate, so the kernel's per-CPU
   accessors fail with "invalid operand for inline asm constraint 'i'"
   — but on every LINUX target zig refuses `-fno-pic` outright ("the
   selected target requires position independent code"). Only zig's
   FREESTANDING target accepts it, and there the kernel's own sources
   compile clean, integrated assembler and per-CPU accessors included
   (`zigcc_probe6.sh`). So the wrapper sends non-PIC compilations to
   `<arch>-freestanding` and leaves PIC ones (the VDSO, a real shared
   object that asks for `-fPIC`) on the Linux target, where zig's
   requirement is exactly what the VDSO wants. Getting that division
   wrong shows up as "R_X86_64_32 against hidden symbol" at the VDSO
   link. Real mode asks for non-PIC in the third spelling, `-fno-pic`.

## What was measured

- **The tree builds.** After the four concessions: 478 options (gcc's
  configuration of the same fragment has 483 — the kernel's own Kconfig
  differs for clang), **bzImage 1,446,912 bytes in 1m40** at two jobs
  (gcc: 1,217,536 bytes, 78 s).
- **The image does not boot.** Under QEMU it prints nothing at all —
  not even `earlyprintk` from the decompressor, which speaks before any
  console exists (`zigcc_boot_diag.sh`). It dies in the 16-bit setup
  code, the part this wrapper pushed onto a target the kernel never
  intended.

## The verdict, and the claim narrowed

gcc keeps building the kernel of every image. The architecture table no
longer says `zig cc` builds it; it says gcc does, that zig cc was
attempted on this date, and where it stopped. A compiler that produces
an unbootable image is not a sovereignty gain, and saying otherwise
would be the kind of claim this repository exists to refuse.

What is kept: the instrument, whole — `zigcc_fetch.sh` (pinned),
`zigcc_wrapper.sh` (every concession stated in its own comments),
`zigcc_kernel.sh`, the six probes, and `STZOS_CC=zigcc` in the image
pipeline. A later zig, or an `LLVM=1`-shaped attempt with lld and the
LLVM binutils, starts where this stopped rather than from nothing.

## Named seams

- The 16-bit setup code is the suspect: the freestanding target is a
  poor fit for `-m16 -march=i386`. A next attempt should keep the
  kernel's own target and find another way past the PIC requirement
  (a zig that allows `-fno-pic` on Linux targets would end it).
- `ld.lld` is not a zig subcommand, so a full LLVM build is not
  reachable through zig alone; the linker and binutils would stay the
  distribution's in any case.
- **The estate's own mirror of the kernel tarball** is a ROUTED ERRAND,
  not done: 148 MB exceeds a git file limit, so availability needs
  storage the author picks (a private release asset, a bucket, a second
  machine). Integrity is already sovereign — the digest is pinned and
  verified on every fetch — and this errand is about availability only.

---

# RDY-1 — a daemon's own word: READY, and the hole it closes in the A/B trial

Ordered by the author on 2026-09-12 ("take whatever decision you think
suitable on my behalf, and then do the tasks in the order you
suggested"), first of four. The decisions taken, and open to reversal:
**the signal is a file**, not a socket — any program in any language
can create a path, and it is visible from outside; **there is no
timer** — a timer would race a boot, while a wait does not, and a box
that will not commit an update whose world never came up is behaving
correctly; **READY is refused on a one-shot**, whose readiness is
already its exit 0; **the court is the rehearsal**, where a live
daemon is natural and no kernel is needed.

## The hole it closes

AB-1 left a daemon ready the moment it was SPAWNED. The box's real
worlds will be daemons, so under that rule an A/B trial could commit
itself while the kitchen display was still opening its socket — an
update judged good by a machine that had not yet served anyone. The
commit condition is `every service is ready`; giving a daemon a way to
say when that is true closes it without touching the commit rule.

## What was built

- **`READY "<path>"`** on SERVICE, fixture-first (A13, R43, R44, R45;
  **58/58 on the first run**): the absolute path the service creates
  when it is serving. Refused on a one-shot, refused if not absolute,
  and one path signals for one service. `machine.stzu` gained the seat
  (counts unchanged: it is a seat, not a kind).
- **PID 1 waits for the word** (`src/init.zig`): a daemon with READY
  is ready when the path appears, never before; the reaper polls for
  it a quarter second at a time, prints `boot: <name> -- ready
  (<path>)` when it comes, and starts what waited. A daemon that never
  signals never becomes ready: its dependents never start, are named
  at the end (`what it comes AFTER never signalled ready`), and the
  A/B commit never happens.
- **The instrument names what it cut short**: with `--turns`, the run
  now also prints each service still waiting and why, so the negative
  case is read off the transcript instead of inferred from silence.
- **The image gives the signal a home**: the parent directory of each
  READY path joins the initramfs (the root is RAM and writable, so a
  directory is all the image owes it).
- **The rehearsal is the court** (`machines/wsl_rehearsal.machine`):
  `signals` is a daemon stand-in that creates its path and stays alive
  (`flock <path> sleep 30` — creating the path IS what flock does
  before running its command), `after_signals` starts on the signal;
  `mute` runs and never signals, `after_mute` never starts. The script
  removes both paths before each run: a stale signal would make a
  daemon ready before it ever started.

## What was measured

- The rehearsal and the namespace PID 1: `signals -- ready
  (/tmp/stzos-signals.ready)` followed by `start after_signals`, and
  at the end `after_mute has not started -- what it comes AFTER has
  not signalled ready`. Both sides print.
- The three images unchanged and judged identical: 28, 22, 49 lines.
  None of them declares READY yet — the box's worlds are stand-ins
  that exit, so they are one-shots — which is why the pins did not
  move. When the real worlds arrive as daemons, they declare READY and
  the pins move with them.

## Named seams

- A bounded window for a trial (deliberately not a per-service
  timeout): if the box should give up on an update after some minutes,
  that belongs to the trial, not to the service.
- Health beyond "it said it was serving": a health seat, and the
  question of whether a signal should be withdrawn when a world stops
  serving without exiting.

---

# AB-1 — two slots: an update is a trial before it is a commitment, and the card is the witness

Ordered by the author on 2026-09-12 ("start them in order one by one",
second: A/B slots with watchdog rollback).

## What was built

- **`SLOTS "<device>"`** on MACHINE, fixture-first (A12, R41, R42;
  54/54): the boot partition that holds `config.txt` and two slots.
  Needs a board whose firmware can try a slot (`rpi4`); the emulator
  boards load the kernel directly and are refused by name. The plan
  carries a `slots` step; `makeen_box.machine` declares
  `SLOTS "/dev/mmcblk0p1"`.
- **The card's layout** (`src/image.zig`): `slots/A/` and `slots/B/`
  each hold `kernel8.img`, the dtb, `initramfs.cpio` and a
  `cmdline.txt` carrying `stzos.slot=A|B`; `config.txt` names the
  committed slot in `os_prefix` and, under the firmware's own
  `[tryboot]` filter, the other. The same image fills both slots at
  first.
- **PID 1's slot logic** (`src/init.zig`): after the mounts it reads
  which slot booted (`stzos.slot=` on `/proc/cmdline`), mounts the
  boot partition, reads which slot is committed, and says whether this
  boot is steady or a trial. It arms the hardware watchdog by opening
  `/dev/watchdog`, feeds it from a polled reaper loop (a quarter
  second between looks), and on a trial COMMITS — rewriting
  `config.txt` so the two prefixes swap, synced — only once every
  service is READY (a one-shot exited 0, a daemon spawned): a
  one-shot that fails, or a service its failure held back, keeps the
  trial uncommitted and the rollback is the answer. A steady boot
  commits nothing. The magic close
  disarms the watchdog before a clean restart. `--hold` is the
  rollback instrument: never commit; with a watchdog armed, stop
  feeding it and let the hardware answer; without one, restart as any
  uncommitted trial ends.
- **`stzos update <dir>`** (`src/update.zig`): the file half — read the
  committed slot from `config.txt`, refuse unless every file of the
  new image is present, write the OTHER slot, sync — and the reboot
  half, a restart with the argument `0 tryboot`. `--boot <dir>`
  rehearses the file half on any directory; `--no-reboot` stops after
  writing. Rehearsed on the host with its negative (a missing file
  refuses before a byte is written).
- **The judge**, doubled: after the trial boot the script reads
  `config.txt` back from the card image; then boots a PRISTINE copy of
  the card with the trial held and reads that card back too. Both
  readings are lines of the pinned transcript.

## What was measured

- The trial boot under `raspi4b`: `slot B -- a trial (committed is
  A)`, the worlds run, **`slot B -- committed: every service is
  ready; config.txt now boots B, A is the fallback`**, and the card
  read back says `os_prefix=slots/B/` first. The held trial on the
  pristine copy: the same trial, `held, not committed`, a restart,
  and that card still says `os_prefix=slots/A/`. Pinned, 49 lines.
- `stzos update` on a fake boot partition: slot B written (four
  files), `config.txt` untouched; with `cmdline.txt` removed, refused
  whole.

## What was found

1. **QEMU's raspi4b resets the board the moment the watchdog is
   armed.** Its power-management model has no countdown and reads the
   driver's "full reset on expiry" bit as "reset now"; the first trial
   boot vanished after the capability lines with its buffered output,
   and the card was unchanged. The emulator's boot line now carries
   `stzos.watchdog=off` (never the card's `cmdline.txt`), PID 1 states
   that a trial cannot roll back by hardware there, and everything said
   before arming is flushed first, so a board that resets on arming can
   never take the transcript with it.
2. **mtools asks on stdin when a name clashes.** `mmd` on a directory
   that already existed opened its interactive clash prompt on a pipe
   that never closes; the card assembly hung thirty-three minutes.
   Every mtools call now runs with `-D s` or `-D o` and stdin from
   `/dev/null`; `wsl_cleanup.sh` ends what it left behind.
3. **The held trial must run on a pristine card.** The first hold ran
   on the card the trial had just committed, so it was steady, not a
   trial, and the instrument measured nothing. The card is copied
   before any boot writes to it.
4. **Mainline's watchdog driver ignores the restart argument**, so
   `0 tryboot` is a plain restart on this kernel: the firmware's
   tryboot flag cannot be raised from it without a patch to
   `bcm2835_wdt.c`. The file half of an update is complete; the
   one-shot trial request is the board's first task.
5. **A half-written slot is refused before it is written.** The
   rehearsal's negative left three files behind; every source is now
   checked first.
6. **Committing on "started" raced the transcript**: the commit line
   landed between the last one-shot's output and its exit, on timing.
   Committing on "ready" (exited 0 for a one-shot) is both the
   deterministic order and the right rule: a failed one-shot never
   commits.

## Named seams

- The tryboot flag: a vendored patch to the watchdog driver (parse
  the restart argument, set the flag in `PM_RSTS`), done with the
  board and the firmware documentation in hand.
- Health beyond "every service started": a health seat, and a bounded
  window for a trial.
- The hardware watchdog's real countdown, on the board.

---

# NET-1 — the NETWORK kind: a machine declares its wire, PID 1 brings it up, a lease judged in the emulator

Ordered by the author on 2026-09-12 ("start them in order one by one",
the NETWORK kind first), while the hardware for OS-5 is on its way.

## What was built

- **`DEFINE NETWORK`**, fixture-first (A10, A11, R36–R40; 51/51 on the
  first run): `INTERFACE`, `ADDRESS dhcp | "a.b.c.d/n"`, and for a
  static address `GATEWAY` and `DNS`. One network per interface; the
  `network` capability must be granted; a dhcp network may not declare
  what it learns; addresses are parsed at check time. `machine.stzu`
  gained the declaration and a `server` form (6/5/0/3, accepted by
  stz's meta-court). The plan carries a `network` step after the
  capabilities and before the services.
- **PID 1 brings the networks up** (`src/netcfg.zig`), like mounts,
  before any service: static through four ioctls and a fifth for the
  default route (`SIOCADDRT` with the kernel's `rtentry`, laid out by
  hand — the stdlib has no such table); dhcp through a client written
  here: DISCOVER, OFFER, REQUEST, ACK on a broadcast UDP socket bound to
  the interface, three tries of three seconds, the lease's address,
  mask, router and DNS applied. Every result is one transcript line.
- **`stzos net`** by hand does the same: `<iface> <cidr> [gateway]` or
  `<iface> dhcp`.
- **The emulator's oracle**: when a machine declares a NETWORK, the
  image gives `qemu_pc` and `qemu_virt` a virtio NIC on QEMU's
  user-mode network (`-netdev user`), whose built-in server leases
  `10.0.2.15` with router `10.0.2.2` and dns `10.0.2.3`. The kernel
  fragment gains the IP stack and the NIC. The Pi has GENET already.
- **The box's file**: `makeen_box.machine` declares `NETWORK lan` static
  at `192.168.10.1/24`, no gateway (the box is the gateway), and the
  `network_up` service is gone; `makeen_qemu.machine` declares
  `ADDRESS dhcp`.

## What was measured

- `makeen_qemu` on `virt`: **the lease on the first try** —
  `network lan -- eth0 up 10.0.2.15/24, gateway 10.0.2.2 (dhcp), dns
  [10.0.2.3]`, then both worlds; pinned, 22 lines. The kernel gained
  the IP stack and virtio-net: 2m40 for the rebuild.
- `makeen_box` under `raspi4b`: the static network refused `NODEV` (no
  Ethernet in the emulator), the worlds now run since a refused network
  holds nothing back; pinned, 21 lines. `qemu_hello` unchanged, 28.

## What was found

1. **A NETWORK is a mount, not a service.** OS-4 had the box bring its
   interface up through a `network_up` service, and the worlds came
   AFTER it, so in the emulator they never started. Declaring the wire
   as a kind of its own puts it where a mount is: before the services,
   stated, and not a gate. The worlds now run in both emulated boxes.
2. **The kernel's route ioctl takes a struct the Zig stdlib does not
   carry**: `rtentry` is laid out by hand from the uapi header, 64-bit
   fields and padding included. The emulated lease sets a default route
   through it and the kernel accepted it; on a machine where the route
   already exists `EEXIST` is treated as success.
3. **QEMU's user-mode network is a complete oracle for dhcp**: a
   deterministic lease with no hardware, and the transcript pins it.

## Named seams

- Lease renewal (the box takes its address once, at boot), a DNS
  resolver, the box as a DHCP SERVER for the phones, IPv6.
- A readiness signal for daemons; `RESTART always` worlds in
  `makeen_box.machine` once the real worlds are daemons (the stand-ins
  exit, so they are `never` today).

---

# OS-4 — the real box: a Raspberry Pi 4, its SD card image, and the same board emulated to judge it

Ordered by the author on 2026-09-12 ("choose the board on my behalf and
go for OS-4"). The board ruling is in `doc/PROVENANCE.md`
(STZ-OS-BOARD-01): the Raspberry Pi 4 Model B.

## What was built

- **The BOARD clause**, fixture-first: `qemu_pc`, `qemu_virt`, `rpi4`,
  defaulting by ARCH, hosted-only, coherent with ARCH; A9, R33, R34, R35
  are the board's own, A1/A3 carry the defaults, A2 is
  `machines/makeen_box.machine` verbatim with `BOARD rpi4`. **44/44**;
  the court convicted the implementation once on R35 (the ARCH check
  ran before the profile check; reordered, the fixture kept).
  `machine.stzu` carries the seat; the plan and the init print the board.
- **`stzos net <iface> <a.b.c.d>/<n>`** (`src/net.zig`): a role of the one
  binary — four ioctls on a datagram socket, every result stated, no
  DHCP, no gateway, no DNS. The box's `network_up` service is now a
  program that exists: `RUN ["/stzos", "net", "eth0", "192.168.10.1/24"]`.
- **The rpi4 target** (`src/image.zig`): the arm64 kernel with the
  BCM2711 platform, the mini-UART and PL011, the mailbox and firmware
  driver, the watchdog (which is also how the board restarts), SDHCI
  for the card, GENET for Ethernet; the device tree
  `bcm2711-rpi-4-b.dtb`; two consoles (`ttyAMA0` for the emulator's
  PL011 on the header pins, `ttyS1,115200` for the board's mini-UART
  there); `sd.list` (the card's partitions and the boot partition's
  files), `config.txt` and `cmdline.txt` written by the derivation.
- **Two device trees from mainline's, both derived** (`DTB_OPS` and
  `QEMU_DTB_OPS` in `image.env`, applied by `experiment/dtb_ops.py`,
  every op printed): the CARD's tree adds the mmc aliases mainline
  lacks, so `/dev/mmcblk0p2` is a fact and not a probe-order race; the
  EMULATOR's tree disables the two AON blocks QEMU does not model and
  opens the legacy SDHCI where QEMU plugs the card, aliased as mmc0 so
  the declared device name holds in both worlds.
- **The SD card image** (`experiment/os2_image.sh`): a 256 MiB card
  (QEMU wants a power of two), p1 FAT32 64 MiB with the firmware's
  `start4.elf`/`fixup4.dat` (raspberrypi/firmware, tag `1.20260907`,
  pinned by sha256 in `vendor/rpi-firmware/PIN.txt`, gitignored),
  `config.txt`, `cmdline.txt`, `kernel8.img`, the card's DTB, the
  initramfs; p2 ext4 64 MiB, the declared `/data`. `sd.img` is what a
  card gets `dd`'d with.
- **The judge**, unchanged: the same board under QEMU `raspi4b`, the
  transcript against `machines/makeen_box.expected`.

## What was measured

- arm64 kernel for the board: 689 options, `Image` 5.6 MB, **2m50** wall
  at two jobs for the first build; the card 256 MiB; the initramfs
  4.4 MB.
- Boot under `raspi4b` (QEMU 10.2 TCG): `Machine model: Raspberry Pi 4
  Model B`; PID 1; `proc` `sysfs` `devtmpfs` done; **`mmcblk0: p1 p2`,
  `ext4 at /data -- done`** on the card's second partition by its
  declared name; `gpio` refused as declared; `network_up` ran `stzos
  net eth0` and got **`no such interface (NODEV)`** — QEMU disables
  GENET itself, the emulator has no Ethernet — so `kds` and `poste`
  **never started** by the readiness rule, named; `reboot(RESTART)`
  through the BCM2835 watchdog; QEMU exit 0. Pinned, 17 lines: the
  emulator's truth. On the board, Ethernet exists and the worlds start;
  that difference is OS-5's first finding, expected and stated.

## What was found

1. **QEMU's raspi4b faults on the AON block.** The first boot printed
   nothing: `brcmstb_l2_intc_of_init` took a synchronous external abort
   at 0x7ef00100 (the AON L2 interrupt controller); with it disabled,
   `clk_disable_unused` took the same abort in `clk_gate_readl` on the
   DVP clock at 0x7ef00000. Found with `earlycon=pl011,mmio32,0xfe201000`,
   `initcall_debug`, and `System.map` (tinyconfig has no KALLSYMS;
   `experiment/os4_syms.sh` resolves the addresses). QEMU disables pcie,
   rng, thermal and genet on its own; these two it misses. Both are
   named in the emulator's tree and nowhere else.
2. **QEMU plugs the card into the legacy SDHCI**, not into emmc2 where
   the board's card sits; mainline gives that host to the Wi-Fi SDIO
   (non-removable, with a power sequence). The emulator's tree opens it
   as a plain removable host. `mmc0: SDHCI controller on fe300000.mmc`,
   `mmcblk0: mmc0:2804 QEMU! 256 MiB`.
3. **Mainline's rpi-4-b tree has no mmc aliases**, so the card's index
   is probe order once the Wi-Fi host probes too. The board's tree pins
   `mmc0` to emmc2. A declared device name must be a fact.
4. **The mini-UART driver hides behind two menus** (`SERIAL_8250_EXTENDED`,
   `SERIAL_8250_SHARE_IRQ`); the build's dropped-option check named it.
5. **QEMU's SD model wants a power-of-two card**; the first 130 MiB
   image was refused. 256 MiB, partitions at the front.
6. **The Bash tool cannot pass `$` or `&` through `wsl.exe`** in a
   one-line `bash -c`; every WSL act is a script file.

## Named seams

- The board itself: this card has not touched a Pi. The first real boot
  will differ from the pin where the emulator lacks the hardware
  (Ethernet, the AON block) and nowhere else, or that is a finding.
- The Wi-Fi firmware blob (not taken); DHCP, gateway, DNS (the NETWORK
  kind); A/B slots with watchdog rollback (the watchdog driver is in);
  `make CC="zig cc"`; the judge into `stzos judge`.

---

# OS-3 — the Makeen box: the aarch64 image, a persistent partition, and AFTER made deterministic

Ordered by the author on 2026-09-12 ("take decision on my behalf on the
waiting rows, and then go for OS-3, the aarch64 image for the Makeen
box"). The three rulings are in `doc/PROVENANCE.md` ("The rulings of
2026-09-12"); the mailbox is `softanza/mailbox/stzos.md`.

## What was built

- **`stzos image` for aarch64**: one `Target` table per architecture
  (kernel ARCH and cross prefix, the kernel artifact, the QEMU machine,
  the console, the serial and block kconfig, the virtio transport —
  virtio-mmio on `virt`, virtio-pci on `pc`). The derivation now emits
  `image.env` (what the build must be told, written from the
  declaration alone before any staging check) and `disk.list` (the
  block devices the declared mounts need; one per image today, a
  second is refused by name). The boot line carries the virtio disk.
- **`experiment/os2_image.sh` made arch-aware**: one kernel tree per
  ARCH under `$HOME`, the cross compiler from the derived prefix, the
  kernel artifact by its derived path, the disks made with `mkfs` from
  `disk.list`, and a check that every option the fragment asked for
  survived `olddefconfig` — a dropped one is named as a missing
  dependency.
- **`machines/makeen_qemu.machine`**: the Makeen box as QEMU's `virt`
  can carry it — aarch64, the PL011 console, a 64 MB ext4 disk at
  `/data` on `/dev/vda`, the `kds` and `poste` worlds as stzr services.
  `makeen_box.machine` (fixture A2) stays the box's own truth with its
  SD-card partition and its network service; the two converge when the
  box is real.
- **stzr for aarch64**: stz's runtime cross-built for aarch64-linux-musl
  (764 KB static) with one flag; the toolchain in WSL gained
  `gcc-aarch64-linux-gnu`, `qemu-system-arm`, `e2fsprogs`.
- **AFTER waits for readiness** (`src/init.zig`): a one-shot (`RESTART
  never`) is ready when it has exited 0, a daemon (`always`,
  `on_failure`) as soon as it is spawned; a one-shot that fails blocks
  its dependents for good and init names them (`never started -- it
  comes AFTER x, which exited 1`). Services start when eligible, from
  the reaper loop, in plan order. `GRAMMAR.md` carries the rule.

## What was measured

- arm64 kernel: 531 options, `Image` 3,768,328 bytes, **2m01 s** wall at
  two jobs for the first build (3m27 user), 27 s for the reconfigure.
- Boot on `virt` (cortex-a53, 512 MB, TCG): PID 1, `proc` `sysfs`
  `devtmpfs` done, **`ext4 at /data -- done`** on the virtio disk,
  `gpio` refused as declared, `kds` read the machine file that rode in
  the image (7 declarations), `poste` started only after `kds` exited 0,
  both exited 0, `reboot(RESTART)`, QEMU exit 0. Pinned:
  `machines/makeen_qemu.expected`, 20 lines.
- x86 re-judged under the readiness rule: `hello` now starts after
  `self` exits, the transcript is deterministic; `qemu_hello.expected`
  re-pinned in this commit for that named reason (28 lines).

## What was found

1. **`init=` was the wrong parameter and x86 booted by accident.** The
   root IS the initramfs; with `init=` the kernel looks for `/init`,
   finds none, and goes to mount a root DEVICE. The x86 kernel had no
   block layer, so `mount_root` did nothing and the boot proceeded; the
   arm64 kernel had `CONFIG_BLOCK` for its ext4 mount and panicked
   `VFS: Unable to mount root fs on unknown-block(0,0)`. `rdinit=` is
   the honest parameter and both machines boot with it.
2. **Menus tinyconfig closes drop the fragment's drivers silently.**
   `CONFIG_VIRTIO_BLK=y` and `CONFIG_VIRTIO_MMIO=y` vanished under
   `olddefconfig` because `VIRTIO_MENU`, `BLK_DEV` and `BLOCK` were off;
   the mount failed `NOENT` with no other symptom. The fragment now
   names the three, and the build prints every requested option that
   did not survive.
3. **AFTER only ordered spawns**, and the x86 judge caught it on the
   third boot (the exit lines of `self` and `hello` swapped). The
   readiness rule replaces it; both expectations were re-pinned in the
   same commit as the rule, for that stated reason.
4. **`reboot(RESTART)` inside a pid namespace ends the namespace**: the
   kernel sends the namespace's init SIGHUP instead of rebooting, so the
   WSL PID 1 transcript stops at the `init halts the machine` line and
   `unshare` exits nonzero. The kernel's rule, not a defect; the init's
   comment says so.

## Named seams

- The real box: a board's kernel config and device tree, U-Boot, the SD
  card's partitions (`makeen_box.machine` names `/dev/mmcblk0p2`), A/B
  slots with watchdog rollback.
- The NETWORK kind (`network_up` in A2 names a program that does not
  exist); the USER seat.
- `make CC="zig cc"` for both kernels; a tarball mirror in the estate.
- The judge into `stzos judge`; one virtio disk per image today.

---

# OS-2 — the machine boots: a vendored kernel, an image derived from the plan, QEMU, the transcript judged

Ordered by the author on 2026-09-12 ("install qemu, gcc and make in WSL
and go for OS-2"), the same day as OS-1.

## What was built

- **`stzos image`** (`src/image.zig`): from a judged plan, three texts
  and no toolchain — `initramfs.list` in the kernel's own gen_init_cpio
  format (device nodes for PID 1, the mount points, `/stzos`, every
  program and file the services name taken from a staging root and
  REFUSED if absent, the declaration itself at `/etc/machine`),
  `kernel.fragment` (the kconfig the profile and the declared mounts
  need, merged over tinyconfig), `boot.cmd` (the QEMU line). Hosted and
  x86_64 only today; the rest refused by name.
- **The init's ending** (`src/init.zig`): PID 1 may not exit, so when
  every service has ended it calls `reboot(RESTART)`; under QEMU
  `-no-reboot` that closes the boot and the transcript. In a user
  namespace the kernel refuses it and the transcript says so.
- **The vendored kernel**: Linux 6.12.109 LTS, pinned by digest from
  kernel.org's own `sha256sums.asc` (`vendor/PIN.md`,
  `experiment/os2_kernel_fetch.sh`); the tarball stays out of git (over
  the file limit) and in `vendor/linux/`.
- **The imperative half** (`experiment/os2_image.sh`, WSL Ubuntu):
  stage, derive, tinyconfig + fragment + olddefconfig, `make -j2
  bzImage`, gen_init_cpio, QEMU with the serial console captured, then
  the judge: the transcript normalised (firmware banner and control
  bytes before PID 1's first line, CRs, pids → N) and diffed against
  `machines/qemu_hello.expected`.
- **stzr in the image**: stz's runtime cross-built from `D:\GitHub\stz`
  for x86_64-linux-musl (static, 776 KB, ReleaseSmall) with one flag —
  the first time the Softanza runtime ran on a machine the estate
  declared.

## What was measured

- Kernel: 496 options on, bzImage 1,217,536 bytes, **78 s wall** at two
  jobs (2m08 user) on WSL Ubuntu, gcc 15.2.
- Image: initramfs 4,232,704 bytes — stzos 3.4 MB unstripped, stzr
  776 KB, hello.luau, the machine file.
- Boot (QEMU 10.2, TCG, 256 MB): PID 1, `proc` `sysfs` `devtmpfs`
  `tmpfs` all mounted (`done` × 4 — the namespace refusals of OS-1 were
  the namespace's, not the init's), `self` (pid 15) printed the
  machine's own plan from inside the image, `hello` (pid 16) printed two
  lines from Luau under stzr, both exited 0, `reboot(RESTART)`, QEMU
  exit 0. **The transcript matches the pinned expectation line for
  line, 28 lines**, on the second run (the first run IS the pin, stated
  as such: there was no earlier oracle for a machine that had never
  booted).

## What was found

1. **Port 80 is blocked on this network**: apt over http timed out on
   every mirror address while https answered 200; the toolchain script
   switches Ubuntu's sources to https. `Acquire::ForceIPv4` was a wrong
   first diagnosis (the addresses shown were IPv6, the cause was the
   port).
2. **Extracting the kernel onto the Windows mount took longer than the
   600 s tool budget** and the build there would have been slower
   still; the pipeline extracts and builds in `$HOME` inside WSL, and
   the 1.6 GB stray extraction on the mount was removed.
3. **AFTER orders starts, not completions**: `hello` started after
   `self` was spawned, and the two outputs interleave under the
   scheduler. A completion/readiness seat is a fixture-first widening
   (`doc/ARCHITECTURE.md` §7).
4. **The Bash tool rewrites `/mnt/d/...` paths** handed to `wsl.exe`;
   WSL scripts are invoked from PowerShell.

## Named seams

- aarch64 image and real hardware (the Makeen box); block devices and
  persistent mounts (virtio-blk first); A/B slots; the bootloader.
- `make CC="zig cc"` for the kernel; a tarball mirror in the estate.
- The judge lives in a shell script today; folding it into `stzos
  judge <name>` (portable, like the court) is queued.

---

# OS-1 — the declared machine: language, plan, and PID 1

Ordered by the author on 2026-09-12: a distinct private repository for
the operating layer, designed and built in the Softanza style. This
section records what was done, what was measured, and what was found.
Newest section first, as stz's PROTOCOL.md.

## What was built

- **The machine language v0.1** (`declarative/machine/GRAMMAR.md`):
  five kinds — MACHINE, SERVICE, CAPABILITY, MOUNT, PIN — over the
  Grammar Commons' lexical form, every menu closed, the capability
  vocabulary stzlib's nine names verbatim. Judged by `fixtures.json`:
  8 accepts with structural expectations (identity, counts, service
  order, granted set, folded rationale), 32 rejects each carrying the
  fragment its refusal must contain. **40/40** after one correction
  (below). Pinned in `PINNING.md`.
- **The language declared in stzu** (`machine.stzu`) and judged by
  stz's own meta-court through `experiment/judge_machine_stzu.luau`,
  run by stz's runner from stz's directory: accepted first run —
  5 declarations, 4 forms, 0 expressions, 3 refusals, verbs
  CAPABILITY MACHINE MOUNT PIN SERVICE. Nothing forked.
- **The parser and checks** (`src/machine.zig`), **the plan**
  (`src/plan.zig`: console, implicit mounts, declared mounts, every
  capability granted or refused, pins, services in AFTER order with
  declaration order breaking ties), **the court** (`src/court.zig`),
  **the init** (`src/init.zig`: mounts by syscall with each result
  stated, services spawned as argv, PID 1's reaper with the three
  restart policies), and **the CLI** (`src/main.zig`), one static
  binary.
- **Two Linux targets by one flag** (`zig build cross`:
  x86_64-linux-musl and aarch64-linux-musl, static, ~3.4 MB unstripped).

## What was measured

- The court, probed in fresh processes with a mutated judge before its
  scoreboard was believed: a wrong count on A2 → red (`expected 99 got
  3`); a wrong fragment on R5 → red (`refused for the wrong reason`); a
  valid source posing as a reject → red (`accepted as machine 'hello'`).
  Three reds, each for its named reason, exit 1.
- The init on Windows: refuses by name (`init is a Linux act; this
  binary was built for windows`), exit 2.
- The init under WSL Ubuntu, x86_64 static binary run from the Windows
  mount (`experiment/wsl_boot.sh`, transcripts in `zig-out/wsl/`):
  1. from an ordinary pid without `--rehearse`: refused (`init is PID
     1's act; from pid N pass --rehearse`), exit 2;
  2. `--rehearse --turns 8`: the three mounts narrated and not executed,
     `once` exited 0 and stayed down, `flaky` exited 1 and was restarted
     five times then given up on, `steady` exited 0 and was restarted;
  3. **PID 1 for real** inside `unshare -Urpf --mount-proc`: pid 1,
     children pids 2–10, `proc` mounted (`done`), `sysfs` and `devtmpfs`
     refused by the kernel with `PERM` (a user namespace's rule, stated
     not hidden), the same reaper behaviour, ending `init would now halt
     the machine`.

## What was found (each a finding, not a footnote)

1. **The court's first conviction was of its own implementation.** R20
   expected the fragment `no declaration grants gpio`; the refusal said
   `needs gpio, which no declaration grants`. Same meaning, wrong
   words: the G8 gate fired exactly as designed. The message changed,
   the fixture did not.
2. **Zig 0.15's `File.Writer` writes positionally on a seekable
   stdout.** The first WSL transcript had run 2's refusal overwriting
   run 1's header and the shell's `exit` lines spliced mid-sentence:
   with stdout redirected to a regular file, the buffered writer began
   at offset 0 and `pwrite` over what the shell had already appended. A
   console is a character device and never shows it; a redirected
   transcript always does. Fixed by the streaming writer; recorded in
   CLAUDE.md as a trap.
3. **WSL output cannot be read through the PowerShell tool** (UTF-16
   decoding drops and splices lines), and a multi-command `bash -c`
   cannot be quoted through `wsl.exe` from PowerShell. The script
   writes files on the Windows mount; the session reads the files.
4. **Silence is refusal held up at the machine's altitude**: a service
   needing a capability no declaration mentions is refused at check
   time (R17), which is stzlib's `stzSystemScope` down-constrain law
   with the machine as the target.

## Named seams (stated, not hidden)

- The image (kernel + initramfs) and the QEMU boot: OS-2, blocked on a
  Linux build environment on this host.
- NETWORK as a kind; USER as a seat; restart backoff and budget; kernel-
  level enforcement of refused capabilities per service.
- The edge boot through MicroRing's substrate; the touch build.
- The name (`doc/PROVENANCE.md`).
