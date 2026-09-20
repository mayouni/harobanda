# Site pedagogy — the reader's journey, reviewed

Working document for `site/`. Not linked from any page, not deployed content.

Companion to `DIAGRAMS.md`. That one is about what a page *shows*; this one is
about the order a reader meets it in, and whether the site answers his
questions in the order he actually asks them.

## The reader this was reviewed for

Someone who can write and ship software, has designed systems, and follows
AI. He knows what an operating system is. He is not hostile and not a
beginner — which is exactly what makes him hard, because he arrives holding
**mainstream defaults** and pattern-matches fast:

- an operating system is a thing you install and then configure;
- Linux is already free, so vendor lock-in is a solved problem;
- the cloud is where things run;
- more features is better, and a system with fewer is a toy;
- security means patching and firewalls;
- AI means calling a model.

He does not read to be convinced. He reads to **categorise**, and then he
reads the rest through whatever box he put you in.

## What was measured

Counted rather than felt, so the findings below can be checked:

| | |
|---|---|
| total prose | **6,458 words** over seven pages |
| per page | index 556 · why 1385 · machine 1078 · build 1312 · ai 753 · enterprise 451 · field 923 |
| external links | **zero** |
| calls to action | **zero** — no download, no repository, no command, no contact, no licence |
| how the last page ends | `Start over → Why Harobanda` |
| category words used | `immutable`, once. **Never**: Docker, Kubernetes, NixOS, Yocto, Buildroot, unikernel, Ansible, Terraform, Balena, systemd |
| private vocabulary | judge 33 · declared 42 · sovereign 20 · world 13 · court 11 · trial 9 · envelope 8 · pin 4 — with no glossary anywhere |

## The verdict

**Unusually strong at explanation, unusually weak at journey.**

Almost every page teaches well on its own. The sequence does not. It runs
*deductively* — principles, then mechanism, then application, then proof —
while this reader needs the *inductive* order: a failure he recognises, then
the idea, then evidence it is real, and only then the principles.

And the journey has no exit. A reader who is fully convinced is handed back
to the first page.

## What has been done since

The measurements above are the review's baseline and are deliberately left as
they were taken. A review that quietly updates its own evidence cannot be
checked against what it claimed. This is the record of what changed after it.

- **Finding 2 — placement. Done.** `why.html` gained *Where this sits*, five
  rows naming a container, a declarative distribution, an immutable server OS,
  an embedded build system and a configuration tool, each with the one
  distinction that matters. Talos is named and called the nearest neighbour,
  because a section that places every distant cousin and omits the sibling is
  the omission the reader is certain to notice.
- **Findings 3 and 4 — the origin, the proof, the split. Done together,**
  because closing 3 on its own would have made 4 worse: moving the origin onto
  the longest page would have lengthened it further. The argument was split at
  the seam it already had. `why.html` keeps the **problem** — where this came
  from, what it is not, what is wrong with the three kinds of OS. A new
  `different.html` carries the **answer** — the three differences. `field.html`
  keeps the cases and the honest limits and becomes what its name always
  claimed: the **proof**. A short *what is real today*, including the sentence
  that no customer yet runs a production workload, is mirrored on `index`.

  `why.html` went from 10.4 screens to 5.4; nothing now exceeds 6.7 and
  nothing is under 2.7. Every page still opens with a diagram inside its first
  third, so `DIAGRAMS.md`'s rule survived the restructure. The nav gained a
  seventh item and was measured: it fits from 901px, hamburger below.

- **Finding 6 — the vocabulary. Done.** Eight terms on `machine.html` at 29%,
  before they start doing work. The definitions are the machine's own, from
  `src/learn.zig`, carried across rather than quoted: the source says `stzos`,
  `zig build court` and `machines\`, and the site says `harb`. Printing them
  verbatim would have put a second name for the same thing on the site, and
  editing them while still calling them quotations would have broken LRN-2. So
  the meaning is faithful, the wording is the site's, and the panel points at
  `harb learn --words` as the authority.
- **Finding 7 — the two ejections. Done.** The hardware gate on `index` became
  an intensifier: the section is now headed *whether or not they build the
  hardware*, and choosing the device is something that makes the fit tighter
  rather than something the reader must do to qualify. On `build.html` the
  reassurance now comes **before** the seven proper nouns instead of after
  them — *bring what you already have*, anything that compiles to a
  self-contained Linux executable, and there is no ecosystem you have to join.
  The family is headed *none of it obligatory*.

  One cost, recorded: `machine.html` went from 6.7 screens to 7.8 and became
  the longest page. That was finding 4 one page over, and it was split rather
  than left — see below.

- **Finding 4, again, one page over. Done.** `machine.html` reached 7.8
  screens after taking the vocabulary panel, so it was split at the seam it
  already had: everything up to the four promises answers *what it is and
  what it changes*, and the last section answers *what it is like to run
  one*. That became `running.html`. machine went 7.8 to 5.7; the new page is
  2.8. The nav now carries eight items and the hamburger breakpoint moved
  from 900 to 1000, measured rather than guessed: eight items and the
  wordmark collide below about 990.

  `running.html` is the only page with no diagram, deliberately. The loop it
  would want is diagram 9, which already opens `index`, and the page's own
  visuals are three transcripts. Drawing the loop twice would make the second
  one a restatement.

- **Still open: 1 and 5 only,** and they are the same missing artifact — where
  `harb` is published from. Until there is somewhere to point at, the site
  describes an action it never offers and asks to be trusted on the one claim
  whose whole value is that trust is not required.

## The nine questions, in the order he asks them

| # | His question | Where it is answered | Verdict |
|---|---|---|---|
| 1 | What is this? | index, hero | partial — no plain definition |
| 2 | **Isn't this just Docker / NixOS / Yocto?** | **nowhere** | **unanswered** |
| 3 | Why would I want a different OS? Mine works. | why — page 2, 1,385 words | good, but late and long |
| 4 | Is this a toy? Who writes an OS? | machine, *Not a new kernel* | **excellent** |
| 5 | What can actually run on it? | build | good, but defensive |
| 6 | Am I locked into a weird ecosystem? | build, the Haro family | **raises the fear it should settle** |
| 7 | Will security and IT approve? | enterprise, 451 words | thin |
| 8 | Is it real? Who uses it? | field — last page | **excellent, buried** |
| 9 | **What do I do now?** | **nowhere** | **unanswered** |

---

## Findings

### 1 · No call to action, and no way to obtain the thing

The site says three separate times that a machine boots on an ordinary laptop
in an emulator with no hardware, and that `harb learn` is eighteen lessons. It
dangles an action it never offers. There is no download, no repository, no
command to run, no contact, no licence, and the final page returns the reader
to the beginning.

**Fix.** A `try.html` and a real link. See brief A.

### 2 · The site never places itself, so the reader files it wrong

Six thousand words without naming a single thing the reader already knows.
His first mental act is categorisation; absent placement he will settle on
"NixOS with fewer features" — NixOS being *declarative Linux* — and every
later page is then read as a weaker version of something he has already
dismissed.

**Fix.** One honest section, high on `why.html`: what this is not, and why.
See brief B. Placement is not defensiveness; refusing to place yourself does
not stop the reader placing you, it only stops you choosing where.

### 3 · The proof is last, and so is the origin

`field.html` carries both of the strongest trust assets on the site: two real
engagements, and an honest-limits list that openly says no customer yet runs
a production workload. That list is the most credibility-building content
here and it sits at about 65% of the last page.

The African origin has the same problem. It explains *why* the machine
refuses what it refuses. Read last, the refusals look like ideology. Read
first, they look like engineering under constraint — which is what they are.

**Fix.** Move the origin into `why.html`'s opening or onto `index`. Mirror a
short *what is real today* on `index`. Nothing needs rewriting; both already
exist, in the wrong place.

### 4 · The heaviest page sits in the highest-abandonment slot

`why.html` is 1,385 words and 7.8 screens, the longest on the site, and it is
page two — before the reader has any evidence that this is real.

**Fix.** Split it, or promote Difference three (sovereignty, the strongest of
the three) above the other two.

### 5 · The sovereignty claim is unverifiable, by this project's own doctrine

The site says the kernel is pinned source rebuilt by your own toolchain, and
that a machine is one text file plus a short list of exact fingerprints you
can hand to any provider you choose. Then it gives the reader no source, no
fingerprints and no repository.

FLT-1, from this repository's own doctrine: **a claim only its author can
check is not evidence.** The site currently asks to be trusted on the single
point whose whole value is that trust is not required.

**Fix.** The same link that fixes finding 1.

### 6 · Eight private terms, no anchor

*judge, declared, sovereign, world, court, trial, envelope, pin.* Each is
used well in its own sentence; together they accumulate faster than a first
reader can absorb. `harb learn --words` exists in the product and is never
surfaced.

**Fix.** A short vocabulary panel — eight words, one line each, in the
product's own wording.

### 7 · Two places the site ejects its own reader

- `index`, *Who it is for*, opens **"If you build both the software and the
  device it runs on"** — a hardware gate placed immediately before the
  explore grid. Much of the audience does not build hardware and is told, at
  the first branch point, that this is not for them.
- `build.html` introduces Haro, HaroServ, HaroScript, MicroHaro, Softanza,
  Luau and Ring in close succession, at the exact moment the reader is asking
  whether he will be trapped in someone's ecosystem.

**Fix.** Widen the gate to anyone who owns the whole solution, whether or not
he owns the hardware. Introduce the family as *optional* — you may bring any
static Linux binary — before naming any of it.

---

## What is already right — do not touch

- **"Not a new kernel. We didn't reinvent the wheel. We rethought the
  vehicle."** The biggest objection, killed first, on the right page. The
  best pedagogical move on the site.
- **The field examples.** A fridge trips the breaker and the server's address
  moves; the printer comes back on a different number; the shop tablet full
  of things that are not the job. Concrete, recognisable, unarguable.
- **The three roles** — programmer, system administrator, auditor. Good
  audience mapping; each gets his own answer in his own terms.
- **The honest-limits list.** Rare, disarming, and worth more than any claim
  on the site. Its placement is the problem, never its content.
- **`harb learn` with a BREAK IT step.** A guarantee you have only seen
  succeed is a claim; one you have watched refuse you is evidence. Saying so
  in public is persuasive precisely because almost nobody does.

---

## The order of work

1. **Brief A — a `try.html`, and link the repository.** Unblocks findings 1
   and 5 at once. **Blocked** on where `harb` is published from.
2. ~~Brief B — place the site against what the reader already runs.~~ **Done.**
3. ~~Move the origin and the honest limits forward (finding 3).~~ **Done.**
4. Give `index` a plain definition and a stake before the code sample.
5. ~~Split or reorder `why.html` (finding 4).~~ **Done** — it became `different.html`.
6. ~~Add the vocabulary panel (finding 6).~~ **Done.**
7. ~~Widen the hardware gate; make the Haro family optional (finding 7).~~ **Done.**

---

## Brief A · `try.html` — the page that is missing

**The sentence it must make true:** *you can have a declared machine booting
on the laptop you are reading this on, in about fifteen minutes, without
buying anything.*

**What it contains**, in this order:

1. **One file.** The nine-line `hello.machine` already on `index`, repeated
   here as the thing to copy.
2. **One binary.** Where `harb` comes from, for Windows, macOS and Linux.
   This is the paragraph that cannot be written until there is somewhere to
   point at, and it is the whole reason this page does not exist yet.
3. **Three commands.** `harb check`, `harb plan`, `harb boot` — with the
   transcript the reader should see, so he knows when it worked.
4. **Break it.** Change one line, watch the court refuse it by name. The
   site's own argument is that a refusal is the evidence; this is the first
   place the reader can feel one.
5. **Then the tour.** `harb learn` — eighteen lessons, each with a command,
   the lines to look for, and a way to break it.
6. **The source.** The repository, the pinned digests, the licence. Finding 5
   closes here.

**Must not.** No sign-up, no account, no request-a-demo. The site spends six
thousand words explaining that this is a system with no vendor inside it, and
a gated download would refute that argument more effectively than any
competitor could.

## Brief B · Placing the site

**The sentence it must make true:** *this is not the thing you are about to
mistake it for, and here is the one difference that matters.*

A short section, high on `why.html`, before *The gap*. Three or four lines,
each naming something the reader already runs and stating the single
distinction — not a feature table, and not an argument about which is better:

- **a container** packages a process to run *on* somebody's operating system;
  this declares the operating system itself, and there is no host underneath
  it to escape to;
- **a declarative distribution** (NixOS is the one he will think of) declares
  what is *installed*; this declares what the machine *is*, and what is not
  declared does not exist on it — there is no package manager to reach for at
  run time;
- **an embedded build system** (Yocto, Buildroot) produces an image from a
  recipe; this produces an image *and* the court that judges the boot against
  the same file the image came from;
- **a configuration tool** (Ansible, Terraform) converges a machine towards a
  desired state; a declared machine has no state to converge — a change is a
  new image, tried once, rolled back by hardware if wrong.

**Must not.** No competitor is wrong in this section. Each of those tools is
good at the job it was built for, and the reader uses several of them. The
section's only job is to stop him spending the next five pages reading this
as a worse version of one of them.
