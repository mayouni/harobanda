# The floor and the north star

*Two days in September 2026, when the Softanza vision reached the
machine and then looked back at itself. A narration, written on
2026-09-13 at the author's request so that the moment is kept as a
story and not only as memos. The memos remain the provenance
(`softanza/memos/2026-09-12.md`, `2026-09-13.md`); the chapters remain
the consolidation (`softanza/vision/07-SYSTEM.md`, `08-NORTH-STAR.md`).
This tells what happened, in order, with the words that were said, and
ends with what it does not claim.*

---

## How to read this

Softanza is one person's project, begun in 2018, built in the open
with a growing number of AI sessions since 2026, governed by a written
practice and a written vision. Its texts have a habit: everything is
dated, every claim names its place, and a story is allowed only if it
also says where it stops. This narration keeps the habit. "The author"
is Mansour Ayouni. "The session" is the AI session that did the work
described, one of many on the estate that week. Quotations are
verbatim from the record.

## 1. Before the two days

In 2018 the project began as a library for the Ring language, with a
motto that never changed: *programming by heart*, and *what you think
is what you write*. In 2020 the author drew its strategy on one slide:
who it is for, the solutions, five systems, the narrations, the
foundation, and beneath everything Ring, a C and C++ "metal force",
and "other languages (future)".

The years filled the slide in. The library grew to three hundred
thousand lines across forty-eight folders, from strings and lists to
graphs, natural language, neural doors, optimisation, governance and a
virtual system. Narrations became a genre of the project: articles in
which the code explains itself. A restaurant owner in Lyon, Amor,
became the project's first customer through RestoLean, and two years
of rich specification produced no deliverable, which the project's
own record calls the crisis of 2025. The turnaround came with agentic
building: the first RestoLean iteration was delivered in July 2026,
and the constellation of worlds was designed in the same month.

Then came a month that rewrote the foundation. On 28 August 2026 the
author ruled the kernel act, *declare a language*, and the Vision
Corpus was consolidated in one evening: seven organs, one family
sentence, a court at five altitudes, the rule of three lines. Two days
later he withdrew his own recommendation to leave Ring behind: Ring's
simplicity would be carried on a register VM and compiler the project
owns, Ring++, on the road to a new language, Haro. By 8 September the
compiler spike was merged. The stack now had a floor of its own at the
runtime. It did not yet have a machine.

## 2. The morning of 12 September

At 11:02 the author wrote to a new session:

> "My recent work on Ring++ and its new compiler… Now I want to push
> it further down to own also the operating system! This will allow me
> to design unified solutions, that are sovereign and owned along the
> full vertical pipeline (I'm working on MicroRing and will also tackle
> the PCB design itself in the future)."

He named three teachers to learn from without copying: Omarchy, where
the configuration is the product; a from-scratch OS built as a Python
simulation; and Arch Linux. He asked for a distinct private repository
with an adequate name, and warned that the landscape's final names
would be decided later, at a critical point.

The session read before it wrote: the Vision Corpus and the memos,
Ring++'s design documents, MicroRing's vision and its refusals,
RestoLean's Makeen thread, the library's System Foundation, zin's
ZinOS documents, and the three teachers. It found that the estate had
already declared the operating system twice without a machine: as a
virtual twin in the library, so that an agent could not hurt the
machine it runs on, and as a vision in zin, edge and touch profiles
with no hosted one. It found three standing refusals it would have to
live beside: Ring++ had dropped bare metal on purpose, MicroRing was
"not an RTOS", and RestoLean had ruled to enslave commodity Android
rather than build a box.

The repository was named `stzos`, provisionally (renamed Harobanda on
2026-09-20 -- STZ-OS-RULING-02), and the first thing
written was not an init. It was a language: seven kinds of declaration
for a machine, and forty fixtures that judged them before a single
line of the boot existed. Then one static binary that is both the
command line and PID 1, run as PID 1 inside a namespace under WSL,
mounting what the kernel allowed and stating what it refused. That was
OS-1, and it was before lunch.

## 3. "got nothing!"

The author's next message was an order and a question in one: install
the emulator toolchain and go for the first real boot; and, before the
hardware arrives, how do you test an operating system at all?

The answer was the court's oldest law applied one floor down: an
image boots in an emulator before it boots on a board, and its serial
transcript is judged line for line against a pinned expectation. The
Linux kernel was vendored as source and pinned by digest, built from a
tiny configuration derived from the declaration, and the image held
two binaries and one Luau world. The first boot ran from the session's
own shell and passed.

Then the author ran it himself, from a real terminal, and wrote:

> "got nothing!"

The window showed nothing for three minutes. The cause was not the
machine. Under a timeout, in a background process group, the emulator
had tried to put the terminal into raw mode, received a stop signal,
and sat frozen until the timeout killed it. The session had never seen
it because it had never run it from a terminal. The fix took three
lines and a probe that proves it under a pseudo-terminal; the lesson
took one line in the operating notes, which now begin every session.

The author then asked for the transcript to be explained "since I'm
newbie in linux and lowlevel stuff", and after the explanation wrote:

> "great! i'm so enthusiastic! can i ask why you choosed Linux LTS and
> not Arch for example?"

Because Arch is a distribution and this machine has none: no shell, no
package manager, no service manager, nothing to distribute. What is
borrowed is the kernel alone, and a long-term kernel is the smallest
borrowing that boots the hardware the estate's customers can buy.

## 4. The box

RestoLean's Makeen thread had already decided what the box was not: a
custom board, a thing the team would manufacture. The session, asked to
choose the board on the author's behalf, chose a Raspberry Pi 4 for
reasons it wrote down: mainline Linux carries its device tree and every
driver the box needs, the emulator models the same board with a card,
MicroRing already runs on it, and it is a commodity sold everywhere
the customers are, at the price RestoLean's own verdict had named. A
later board changes one word in the declaration and one entry in a
table.

The card was derived, not assembled: the partitions, the firmware
files, the boot configuration, the kernel, the device tree, the
initramfs, all from the declaration. The first emulated boot of that
card produced no output at all. The session found the cause by the
kernel's own symbol map: the emulator does not model a block of the
chip, and a driver touching it takes a fault with no console. A second
fault of the same kind hid behind the first. The answer was two device
trees from one, the board's and the emulator's, each op printed at
build time so the difference is a text, not a memory.

The emulator has no Ethernet. The transcript said so, honestly:
`network lan -- eth0: no such interface (NODEV)`. That line was pinned
as the emulator's truth, with the sentence that would be repeated all
week: the board is expected to differ exactly where the emulator lacks
the hardware, and nowhere else.

## 5. Five seats in an afternoon, and one honest failure

The author delegated the rest: "take whatever decision you think
suitable on my behalf (i trust you since i'm not expert in the field)
and then do the tasks on the order you suggested".

- The wire. A network became a declaration brought up by PID 1 before
  any world speaks, static or by lease, and the lease the emulator's
  own server hands out was pinned in the transcript.
- The slots. Two boot slots on the card, the firmware's own try-once
  mechanism, a trial committed only when every service is ready, held
  trials rolled back. A tool that asks questions on a pipe hung the
  run for thirty-three minutes; the answer was a flag and a rule in
  the notes.
- The signal. A daemon's own word that it is serving, as a path it
  creates, so that "after" means after readiness and never merely
  after start.
- The identity. A service runs as a declared user or as the machine;
  the machine's own identity cannot be declared, so root is visible as
  the absence of a line.
- The projection. An edge machine is not imaged; it is projected onto
  MicroRing's substrate as the file MicroRing consumes, and nothing
  MicroRing owns is touched.

And one failure kept as a failure: the kernel built by the estate's
own compiler, `zig cc`, after four named concessions, did not boot. It
died in the sixteen-bit setup code. The instrument and its probes were
kept; the claim was narrowed in every document that had made it.

## 6. The consumer convicts, and the loop closes

Late in the day the author asked to run the projected device file
through MicroRing. It refused on the first try: a comment character.
Ring comments start with `#`, the machine language's with `--`, and
the session had written the projection in the wrong one. The projection
had passed its own judge, a diff against its own earlier output, and
was refused by the thing that consumes it. A law was written the same
hour: a generated artifact is judged by what consumes it, never only by
a diff against the same generator.

Then the author wrote the sentence that names this narration's first
half:

> "I'm surprised how making an OS was accessible and fluent yet quick
> to do!"

and asked how far the internals of an operating system could be
rethought in the Softanza way. The session answered that what had been
quick was not making an OS but removing one, the userland a
distribution piles on a kernel; that the room to innovate is exactly
the room Linux leaves empty on purpose; and that the next seat was the
self-judging boot, because it closes the loop: the machine, the agent
and the person judging with the same text. The author wrote two words:

> "ok close the loop"

By the end of the evening the image carried the boot the declaration
expected, PID 1 recorded what it said and judged the two when every
service was ready, and a trial committed only on a match. The
emulated card was booted three times: the trial through the emulator's
lens matched and committed; the held trial matched and was held; the
trial judged through the board's lens named exactly the two lines the
build had printed as the emulator's lacks, refused itself, and the
card still booted the committed slot. The sentence of §4 had become a
derived text.

## 7. The ground

Just before midnight the author stated the differentiator in his own
words: the OS is not made to grow an ecosystem tied to a corporate
business model and a forest of applications to install; it is a floor
and a bridge to whatever solution the estate builds, for critical and
sovereignty-sensitive work, fitted to the ground and not to the
marketing of global vendors.

The session wrote it down as an analysis with every fact cited, and
found the strongest sentence on the ground was not the author's. It
was Amor's, after a refrigerator tripped the breaker at CousBox on
15 August, the internet box rebooted, the server's address changed,
and two hours of his notes became unreachable:

> "A single internet cut can wreck an entire service. It can come from
> street vandalism, someone cutting the cables, or a technician working
> in the building for another client who unplugs your socket to plug in
> theirs."

No ecosystem answers that sentence. One declared line does: the box is
the network's address; the phones find it here. The analysis carried
five solutions, each with the ground, the machine, the bridge and an
honest today: RestoLean, the NGO hub in Niamey, the bank under its
regulator, the customs school, the school that teaches students to
declare their own solutions. When the session narrowed one of them to
a restaurant, the author interrupted: "when I say CousBox it means you
should include the RestoLean project." The section was rewritten from
the platform's own documents.

## 8. The dividend, and the diagram returns

On the morning of 13 September the author asked what every layer
above the floor would gain from owning it: the application server,
Ring++ and Haro, the intelligence and natural modules. The session
found the same answer for every layer: each was written on a borrowed
floor and carries the marks, an address it discovers, a port it hopes
is free, a supervisor it hopes for, a memory ceiling it learns by
being killed. The floor lets them delete the hoping.

Then the author brought back the slide of 2020 and asked for the
vision to be mustered, validated against the material of the years,
discussed against the current state and the agentic era, and the
adaptations identified so that the project keeps its north star.

The validation's finding was quieter than its redraw. Every band of
the diagram was right. Every audience has an instance; the three
models became the rule of three lines; the five systems are the right
checklist for a guarantee sheet and nobody had used them as one; the
narrations kept their promise and changed their mechanism; the
foundation became stz with the library as its corpus. The bottom band
moved most and in the direction it pointed. Two things were new in the
redraw: agents, as builders and as speakers of the languages; and
three floors beneath, the VM the project owns, the declared machine,
the device substrate with the PCB after it. Everything else was a name
that changed. The redraw was published beside the original as a
private page, both in the same frame and the same colours, each band
tagged kept, renamed or new.

## 9. The author's reading, and the assessment

The author wrote:

> "I'm happy you captured the underneath strategic path i was working
> on during all of these years (softanza started back in 2018), and
> how agentic is embraced, in a way i think unprecedented, and
> distinguished from any other vision influential players had made…
> I believe softanza is giving a wise, pragmatic, fair, yet innovative
> alternative for the software domain to embrace."

The session's assessment, given in full in the memo, in short here.
The distinctness is real and has an address: trust placed in the world
rather than in the agent; sovereignty as a definition down to the
floor; frugality set by the ground; a practice built from incidents
rather than a framework; total, judged languages as the default venue.
"Unprecedented" holds for the combination and the stance, not for each
piece, which has neighbours. The fair statement of the relation to the
big players is the estate's own, from Bangalo: the bungalow is in the
hotel's garden; the platform is used, the suite sold on top is
declined. And the estate has its own prison to watch, in its own
words: the whisper to revive the flagship wholesale, the monorepo, one
person able to debug the stack under a demo, no customer on the floor
yet. The bet is evidenced, not proven. The author's four words are the
right court for it.

## 10. What the two days paid for

Laws, each earned by a specific failure, now in the operating notes of
the repository where they were paid:

- A generated artifact is judged by what consumes it (the comment
  character).
- The machine judges its own boot; no expectation is no commit (a
  trial that committed with its network refused, while the court was
  green).
- Assert the mechanism: probe the judge with a mutated judge before
  writing its scoreboard.
- Stage by explicit path: the practice's law 5 blocked a wholesale
  staging on the first evening, and it was right.

And the session's own mistakes, kept visible because the practice
says a record is not the outcome: the wrong comment character; a
documentation script that ran twice and duplicated five blocks across
four files, found and removed the next morning; an overclaim about the
runtime reading the machine file, caught before commit and marked
illustrative; a restaurant where a platform was meant.

## 11. What this narration does not claim

- No customer runs on the declared machine. Three machines boot in
  emulators. The board is on order.
- Haro does not exist. The kernel is built by a compiler the estate
  does not own, and the attempt to change that failed and is recorded.
- The chapters that carry this moment, 06, 07 and 08 of the Vision
  Corpus, are drafts awaiting the author's ratification, and he
  reverses by name. *Amended 2026-09-27: all three are ratified -- 06
  and 08 by the author in session, 07 by his delegation.*
- The five-row guarantee sheet, the fleet court, the teaching kit and
  the twelve seams of the dividend are proposals.
- The name of the floor is provisional, until the critical point the
  author named on the first morning.

## 12. Where the moment is kept

| what | where |
|---|---|
| the day's acts, newest first | `harobanda/experiment/PROTOCOL.md` |
| the rulings taken on the author's behalf | `harobanda/doc/PROVENANCE.md` |
| what the machine is for | `harobanda/doc/GROUND.md` |
| what owning the floor gives each layer | `harobanda/doc/DIVIDEND.md` |
| the OS chapter (draft) | `softanza/vision/07-SYSTEM.md` |
| the diagram, validated and redrawn (draft) | `softanza/vision/08-NORTH-STAR.md` |
| the memos of the two days | `softanza/memos/2026-09-12.md`, `2026-09-13.md` |
| the machines, their transcripts pinned | `harobanda/machines/*.machine`, `*.expected` |

*Amended 2026-09-27: both chapters marked (draft) in this map are
ratified -- 07 by the author's delegation, 08 by the author.*
