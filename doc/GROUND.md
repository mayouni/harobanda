# The Ground — what the declared machine is for

*2026-09-12, evening. The author's angle, stated in his words: "the key
differentiator of our OS is that it is not made to build an ecosystem
around it tied to a corporate business model, and a forest of
applications and services that must be installed. It's a true kernel
and a bridge to whatever solution we want to build, usually for
critical business and sovereign-sensitive solutions." This document
develops that angle and transposes it onto the solutions the estate
actually builds. Every ground fact below is cited to the repository it
lives in; every projection is marked as one. Unratified: an analysis,
not a ruling.*

## 1. The claim

Every operating system a customer can buy is shaped by the business
model of the company that sells it. The account you must sign in with,
the store, the telemetry, the forced update, the licence per seat, the
bootloader that locks in one update, the support that ends on a date
the vendor picks: none of these serve the machine's job. They serve the
ecosystem the vendor's revenue needs, and the forest of applications
and services is not an accident of that ecosystem. It is the product.

The declared machine is shaped the other way round. It has no users to
grow, no developers to court, no store to fill and no vendor inside it.
It has one job: to be the floor under one declared solution, and to
prove that it is. What the machine runs is its closed SERVICE list,
shipped in the image; nothing is installed, nothing is discovered at
run time, and a change to the machine is a new image, tried once and
committed only when the machine recognises its own boot. The solution
is written first; the machine is derived from it.

That is the differentiator in one sentence: **the vendor's OS is shaped
by the vendor's business model; the declared machine is shaped by the
solution's guarantee sheet.**

One correction to the author's wording, in the estate's own terms. The
declared machine is not a kernel. `doc/PROVENANCE.md` rules it: not a
kernel project, not a distribution, not a fork, not a product. The
Linux kernel is one dependency among several, vendored and pinned, and
the only kernel this estate will ever write is the edge one, in
MicroRing's repository, where no Linux fits. What the author means by
"a true kernel" is right in the older sense of the word: the seed, not
the orchard. The declared envelope a world runs inside, and nothing
else on the path. `07-SYSTEM.md` says it the same way: not a kernel, an
envelope.

## 2. What the ecosystem costs the ground

These are not arguments. They are events the estate has already paid
for, each written down where it happened.

| the ecosystem's mechanism | what it did on the ground | where it is recorded |
|---|---|---|
| the bootloader lock | Samsung removed bootloader unlocking on every device, worldwide, in one update (One UI 8, 2025), with no notice | `restolean/livrable/makeen/B9-LE-MATCH.md` §2 |
| the end of support | the Pixel 6's SoC reached mainline Linux three years after the phone shipped, and Google ends its support in October 2026 | B9 §2 |
| the managed fleet | Google's device-management API lets you build your own console, but the agent on the device, the service that applies the rules and the system that holds the enterprise are Google's: "you own the screen, not the power" | `B5-MDM-SOUVERAIN.md` §2 |
| the shared consumer device | a restaurant server in Lyon on a shared tablet running a payment app, a messenger, a video app and a browser: the device is not the job, it is a distraction from it; a broken kitchen tablet costs 45 minutes of reconfiguration | `zin/doc/vision/ZIN_OS_VISION_v1_0.md` Part 1 |
| the discovered network | at CousBox, 15 August 2026, a faulty refrigerator tripped the breaker; each reboot of the internet box changed the server's DHCP lease; the browser partitions storage by origin, and two hours of the owner's written observations became unreachable | `softanza/prompts/22-partition-tolerance-placement.md` |
| the general-purpose floor | a sensor in a Niger cold room "runs on a Linux that needs kernel updates, package management, SSH hardening and systemd configuration, none of which relate to the sensor's actual job" | ZinOS vision, Part 1 |

The owner's reaction at CousBox was not a bug report. It was a
requirement: "a single internet cut can wreck an entire service. It can
come from street vandalism, someone cutting the cables, or a technician
working in the building for another client who unplugs your socket to
plug in theirs." No ecosystem answers that sentence, because the
sentence is about one restaurant's floor, and an ecosystem is about
everyone's.

## 3. The inversion: the guarantee sheet becomes the machine

RestoLean wrote the answer before this repository existed. MakeenOS,
its documents say, is "a posture, never a marriage": a sheet of
guarantees that imposes itself over whatever host is underneath. Four
guarantees, in Amor's French: *toujours joignable, nom stable, journal
local durable, traverse la coupure* (`B8-ASSERVIR-LE-GRAND-PUBLIC.md`,
`B9` §5). Always reachable, a stable name, a durable local log, survives
the cut.

A `.machine` file is that sheet made executable. Each kind of line is
the answer to one ground need, and the court judges the answer before
any board is bought:

| the ground asks | the declaration says | who judges it |
|---|---|---|
| a stable name: the phones must find the box | `NETWORK lan` with a static address and no gateway: "the box is the network's address; the phones find it here" (`machines/makeen_box.machine`) | PID 1 brings it up before any world speaks; the transcript carries the address |
| a durable log that survives the cut | `MOUNT data` on the card's second partition, mounted by PID 1 before any world speaks | the transcript; the card read back |
| survives the cut, and the technician who unplugs the socket | no shell, no login, a hardware watchdog, two slots, a boot that commits only when the machine recognises it (`SLOTS`, JDG-1) | three card boots in the emulator, pinned at 75 lines |
| the world must be serving, not merely started | `READY` on a daemon: its own word that it is up (RDY-1) | AFTER waits for it; a trial never commits without it |
| who is who on the box | `USER`: a service runs as a declared identity or as the machine; uid 0 cannot be declared (USR-1) | the plan, PID 1 and the service itself answer the same number |
| what the box may touch | `CAPABILITY`, nine names on four kinds, verbatim from stzlib's System Foundation | the plan; the runtime refuses what the machine did not grant |
| commodity hardware, never designed by us | `BOARD rpi4`: one word; a later board changes one word and one table entry | QEMU boots the same board before the card is flashed |
| a change is a trial before it is a commitment | `stzos update` writes the other slot and asks for one trial; the machine judges its own boot against the expectation derived from this file | the card, twice, and now three times |

What is refused is as important as what is declared, because the
forest grows through exactly these doors: no shell on the boot path and
no clause that could put one there; no package manager, so nothing is
installed after the image; no configuration drift, because the machine
is its file. The ecosystem is not refused by policy. It is refused by
grammar.

## 4. The solutions, one by one

Each solution below is real, in the estate, at the stage stated. For
each: the ground, what the machine would say, which tools meet at the
floor, and what exists today. The distinction between a fact and a
projection is kept on every line, because a document that blurs it is
the kind of brochure this angle is against.

### 4.1 RestoLean (CousBox, Lyon): the platform, the constellation, the box, the fleet

**The ground.** RestoLean is a platform for neighbourhood commerce,
"the Shopify of neighbourhood commerce" in its own words, designed
since 2024 with Amor, owner of CousBox, a couscous restaurant in Lyon
and the platform's client zero (`restolean/kb/agents/PROJET.md`). Its
history is the estate's in miniature: two years of rich specification
and no deliverable, a turnaround through agentic building, a first
iteration delivered in July 2026, and on 4 July 2026 the pivot that
inverted the order of the platform: the customer first, with a remote
control page (scan, order, pay) that needs no account; then the
kitchen display and the catalogue workshop; the restaurateur's
management world second; the supplier last. Since that day RestoLean
is not an application but a constellation of worlds on a shared
Commons (identity, catalogue, orders, payments, fleet), governed by
declared norms: the customer stays anonymous, an order is born paid,
VAT is carried by the catalogue, an out-of-stock propagates in two
seconds, undo rather than confirm, and the Verrou itself, "admit the
management world when V1 is in production", written into the
architecture (`kb/agents/CONSTELLATION.md`). RestoPay follows in two
phases, acquiring then issuing. The business partner is paid on the
performance of the co-piloting and never on onboarding, so the
merchant's hardware must cost nothing and be replaceable by the
merchant. Amor's own constraints are the sharpest specification in
the estate: French only, at most two gestures per action, usable
offline in the storeroom, five to fifteen minutes a day, and "my
numbers stay with me."

Two field events then wrote the floor's requirements. On 15 August
2026, the first trial: the refrigerator, the breaker, the internet box
rebooting, the DHCP lease changing, two hours of observations lost.
The resilience brief that followed (`livrable/resilience/`) split "the
network" into five failure domains and showed that the two which
actually stop a restaurant are the router and the single server host,
a laptop with a lid; that a lunch service is time-boxed and cannot be
retried; that a tool which fails once during a rush is replaced by a
paper pad the same afternoon; and that French cash-register law
(inalterability, security, retention and archiving of sales records)
holds in degraded mode too. On 22 August, the installation: the app
reached Amor's phone through six barriers (a corporate device policy,
Samsung's blocker, Play Protect) and the lesson was that the
professional channel is a fleet console with silent forced install,
the way the incumbents ship, and that the vendor's own management API
is not sovereign because its agent, its service and its ownership of
the enterprise stay with the vendor (`B4`, `B5`).

**The machine.** One constellation, three floors, one language.

- *The Commons box.* The constellation needs, in its own words, "the
  smallest server that keeps the promise, not a framework": the
  catalogue, the orders flowing to the kitchen, the payment webhooks.
  That server is the Makeen box, and `machines/makeen_box.machine`
  declares it: a commodity board (B9's verdict, "never designed by
  us"), the card's second partition as the durable journal, a static
  address with no gateway because "the box is the network's address;
  the phones find it here", the kitchen and counter worlds in order,
  two slots. The failure domains are answered where they live: the
  router by a box that hands out the addresses and the names itself
  (B7: `imprimante.makeen` instead of a number to re-type, which
  "solves a problem he has today that has nothing to do with us"); the
  laptop by a machine with no lid, no shell, a watchdog and a boot
  that commits only when it recognises itself; the mains by a restart
  into the committed slot while the kitchen display keeps its local
  queue. The sales journal's inalterability and retention begin as a
  MOUNT and want a signed-journal seat, named, not built.
- *The devices.* The remote control on the customer's own phone, the
  kitchen display on a tablet, the management world on the merchant's
  phone: enslaved commodity Android, the touch profile, MakeenOS as a
  posture over the host. "MakeenOS Ready" as RestoLean defines it, "a
  list of requirements verifiable at installation" rather than a
  manufacturer's reference, is a court by another name. The fleet
  (Paris, Lyon, the franchisees) is a set of machine files; an update
  is an image sent by group through refine's gate, tried once per box,
  rolled back by the box itself. That is the sovereign fleet console
  B5 asked for, without the vendor's agent on the device.
- *The sensors.* The refrigerator that tripped the breaker is the
  ground's own request for the edge profile: a cold-room thermistor
  and its log, `machines/cold_room_sensor.machine`, projected onto
  MicroRing's substrate, and the HACCP evidence zin's fleet agents
  would draw from it as the commercial layer over the open mechanism.
  And RestoPay, when it comes, is the most sovereignty-sensitive world
  of the constellation: an identity of its own (USER), an envelope of
  its own (CAPABILITY), and a floor with no shell for an auditor of
  cash-register software to read.

**The bridge.** RingScript's shape is the remote control: the Ring VM
resident in the page, local-first, a link or a QR as its identity.
RingServ's shape is the Commons role: declared services, embedded
SQLite, sync with local-first pages, one static binary, and the
strategy note of 8 August chose stzlib's own application server as the
Commons for the first demo. MicroRing is the sensor. stzlib gives the
constellation its idiom (stzSuperApp: worlds, bonds, norms, a
Commons) and its offline engine. zin's constitution is what the
constellation's norms become at fleet altitude, and its evidence
agents (HACCP, the cash-register law) the commercial layer. refine's
gate is how an image reaches a franchisee's box. Zing and stzp are how
each world stays a single-file page projected to a phone, a tablet and
the web. And Bangalo is how the project is built: the Verrou, the
notebook that channels new ideas instead of fighting them, and the
project's first law, "the demo does not wait for the foundations",
which is Bangalo's own refusal of frameworks that capture the work.

**Today.** Iteration 1 delivered in July 2026 (the management world
v0.1, the console, the showcase site). The demo of 15 August passed on
the real CousBox catalogue, without payment, on a laptop as the
server, a phone as the remote control and a tablet as the kitchen
display, on the venue's Wi-Fi. The box today is a Galaxy A16 phone as
a hotspot, with two lived limits (B9). `machines/makeen_box.machine`
boots in the emulator with stand-in worlds that exit; the real kitchen
and counter worlds are daemons still to be written; the Commons server
is not yet a declared service of the machine; RestoPay is untouched;
the board is on order (STZ-OS-HARDWARE-01). The guarantee sheet is not
yet a fixture file, and it should be (§6).

### 4.2 DIKO Hub (ONG DIKO, Niamey; bases at Gothèye and Diffa)

**The ground.** A national NGO already connected (Starlink, an office
suite being rolled out) whose daily work runs on fragmented tools:
finance in one package, payroll in another, field collection in
Kobo/ODK, logistics and HR in spreadsheets, coordination on a
messenger. The request (procurement file NY-336-26, answered 31 July
2026, `diko/output/`) is one entry point linking headquarters, the bases
and the field around traceable processes, in eight modules, in three
months. Four requirements decide adoption more than any module: work
offline with deferred synchronisation (ENF3), an interface for people
unfamiliar with computers (ENF4), HAPDP and GDPR compliance with
child-protection and gender-based-violence data that must never leave
the perimeter (ESC6), and total reversibility: DIKO owns the code, the
configuration and the data, with no proprietary lock (ENF10).

**The machine.** This is the solution whose requirements read most like
a `.machine` file already. A hub server declared: `CAPABILITY
inference` granted, because the embedded intelligence runs locally and
sends nothing to an external model; `CAPABILITY network` granted and,
when the seam exists, the box's egress declared rather than assumed
(§6); `MOUNT` for the document store and the ledger of synchronisation;
`USER` per world so that the safeguarding module and the payroll module
are not the same identity. And one box per base: a hosted machine that
runs the field worlds offline on a persistent partition, takes its lease
from Starlink when Starlink is there (`NETWORK ... dhcp`), and receives
updates as images tried once and committed only when its own boot
matches, so that nobody drives to Diffa to reconfigure a server.
Reversibility stops being a clause in a contract: the whole machine is
one text file, one image and a page of pinned digests, which DIKO can
hand to any provider it chooses.

**The bridge.** stzlib's offline engine with synchronisation and
conflict resolution is what the proposal offers; the machine is the
floor it would stand on; zin's regulatory pillar carries HAPDP and GDPR
as declared constraints; refine's audit chain is the traceability the
bailleurs' reports ask for.

**Today.** A preliminary proposal. No machine file exists for DIKO; the
paragraph above is a projection of the requirements onto the language,
and the egress seam it needs is not built.

### 4.3 Sonibank (Niamey; BCEAO and WAEMU supervision, OHADA law)

**The ground.** A small commercial bank where every code change carries
an audit obligation, where the regulator's question is what you can
prove, and where the discipline of Refinement-Oriented Programming was
developed and is being written up as a book (`ayouni/`). The estate
delivered Organizium Standard Edition to the bank (`organizium-sonibank-v1/
delivrable/`): a Python and Flask application on the bank's internal
network with a licence file. The constellation design that would
replace it, `stzSuperApp "Sonibank"`, declares commons of identity,
ledger, payments and messaging (`stzlib/.../STZSUPERAPP_DESIGN.md`). Both
flagships court this bank, and the corpus rules that they must be one
story: zin governs what the bank declares, refine governs how its
software changes.

**The machine.** A bank's server is the place where the ecosystem's
costs are highest and least visible: the shell through which an
undocumented change entered, the account nobody remembers creating, the
update the vendor pushed on a Friday. The declared machine answers the
auditor in the machine's own words. No shell means no undocumented
change exists to find. `USER` per world is separation of duties written
into the floor, and the fact that uid 0 cannot be declared makes root
visible as the absence of a line rather than as a choice someone made.
The boot transcript and the machine's own verdict on it are evidence an
auditor can read without a technician beside them; rendered by stzn,
they are a page. A change to the machine goes through refine's gate as
a refinement, reaches the card as an image, is tried once, and rolls
back by hardware if the machine does not recognise its boot. The audit
chain that ROP builds for the software would then reach the floor the
software runs on.

**The bridge.** refine's gate and audit chain; zin's constitution
(Article 1, explainability; Article 2, reversibility; Article 3, visible
state) applied to the machine's own facts through its Zos pillar, which
declares the platform an organisation is deployed on, while `.machine`
declares the machine itself, one language per altitude; stzr running
the constellation's worlds.

**Today.** Sonibank's production system does not run on stzos, and the
delivered edition is Python. The paragraph above is where the floor
goes when the constellation is built, and the ROP book's data-led pilot
is the empirical test still ahead of the discipline itself.

### 4.4 Customs: the school, and the post

**The ground, customer-validated.** Organizium was proposed to the
Tunisian customs school (École Nationale des Douanes), and four
requirements surfaced (`zin/doc/design/ZIN_ASSESSMENT_ARCHITECTURE.md`):
integration with the school's information system so that KPIs come from
real data; monitoring of transformation plans over time; a companion
toward certification (ISO 9001, ISO 27001, BCEAO and other norms); and
dual-level assessment, of the organisation and of its pedagogy. The
fourth produced the structural insight that every organisation has two
assessment surfaces: how it operates, and what it does.

**The machine.** Level 1 of that model, "how the organisation
operates", includes IT infrastructure, security and internal control,
and an ISO 27001 companion asks precisely the questions a declared
machine answers by construction: what runs on this server, who can
change it, where is the evidence. The machine file is the configuration
baseline; the transcript is the evidence; the court is the control. A
certification companion that assesses a school would, at the floor,
read its machine files and their pinned transcripts instead of
interviewing an administrator.

**The ground, projected.** The same word names an administration. The
Zin book's worked examples put customs officers at a bridge over the
Niger River, and its domain analysis carries customs compliance as a
pillar (declarations, tariff schedules, clearance). A border post is a
Makeen-shaped box with a different declaration: power that fails,
links that come and go, declarations filed locally and synchronised,
and, at the edge, a weighbridge or a barrier as a device machine
projected onto MicroRing. This is a scenario from the book, not a
customer, and is marked as such.

**The bridge.** zin's assessment architecture and regulatory pillar;
stzp's projections to the school's screens; the fleet of a school's
machines judged together (§6).

**Today.** The school is a validated customer requirement for the
assessment product; no machine exists for it. The post is a projection.

### 4.5 ESPA-MT (Niamey): the school that declares its own machines

**The ground.** ZinLab's strategic partnership with the École supérieure
ESPA-MT Niger (2025 onward, `zin/doc/business/igf-niger/`): a long-term
programme in algorithmic thinking, artificial intelligence and digital
governance, whose stated principle is that students are trained "not
to use imported AI tools but to design, declare and govern their own
solutions", because "governance cannot be imported; it is built locally,
with the country's skills and values." The IGF Niger panel of April 2026
framed the same idea for decision-makers: declare before executing;
govern by constitution, not by surveillance; make governance accessible.

**The machine.** A `.machine` file is the smallest complete instance of
the whole method, and it is learnable in an evening, which is the
alphabet's own test for a language. A student on a laptop with no
hardware declares a machine, runs the court and reads a refusal in the
language's own words, prints the plan, derives the image, boots it in
the emulator, reads the transcript, changes one line, and watches the
court convict the change. The 52 pinned rejects of the fixture file are
a curriculum: each one is a rule of the floor stated as the sentence
that violates it. A lab of commodity boards runs the same image; nothing
a student learns can be withdrawn by a vendor at the end of the course,
because nothing on the path has a vendor. The Zina to Zin lossless
export means the student who declared a machine this year declares a
constitution next year in the same act.

**The bridge.** stz's meta-court judges the machine language's own
declaration, so the language the students learn is itself a declared
language; stzn narrates every run; Bangalo is how the estate builds
with AI in the open, the practice the programme teaches.

**Today.** A partnership and a programme, not a deployment. The
teaching kit (one script, one laptop, one boot) is a projection worth
building because it costs almost nothing: the emulator court already
exists.

## 5. Who meets at the floor

The author's angle has a second half: the OS is a bridge, and it
cooperates with the other tools rather than replacing them. This is the
table of that cooperation, each seam marked real or queued.

| tool | what it brings to the floor | what the floor gives it | the seam today |
|---|---|---|---|
| **Softanza / stzlib** (System Foundation) | the capability vocabulary, nine names on four kinds, verbatim; the law rehearse, plan, commit; the virtual twin an agent cannot hurt the machine with | the twin's declaration one floor down, as PID 1 | real: the vocabulary and the law are in the language |
| **stz / stzr** | the runtime that runs every world in the image; the meta-court that judges `machine.stzu` | the only other binary on the boot path | real: stzr boots three machines; the meta-court accepts the language |
| **Ring++** | Linux-class devices, the register VM and the compiler on the road to Haro; one day, the compiler that rebuilds the kernel | a machine whose worlds it can run natively | queued: bare metal is refused by name; `zig cc` on the kernel measured and failed (ZIGCC-1), instrument kept |
| **MicroRing** | the edge substrate: the tiers, littlefs, the cooperative loop as scheduler, the Device seam | a `device.ring` projected from a `.machine`, judged by MicroRing itself | real: the sensor projects and runs (PRJ-1, PRJ-2) |
| **RingServ** | the shape of the box's server role: declared services, embedded SQLite, sync with local-first pages, one static binary | the declared machine it runs on, with its network and partition brought up before it speaks | by design: the server projection under stzp (03-PRODUCTS); no server world is declared as a machine service yet |
| **RingScript** | the phones' faces: the Ring VM resident in the page, local-first, the remote control | the stable address the pages find | by design: the touch profile is design only |
| **Zin** | the constitution over the fleet; the Zos pillar declaring the platform an organisation is deployed on; the regulatory pillar; fleet agents (health, rollout, HACCP evidence) as the commercial layer | machine files as the facts its articles judge; transcripts as evidence | queued: one language per altitude is ruled; the fleet-of-machines court is not built |
| **Refine** | the gate a change must pass; the audit chain; the refinement as the unit of change | the A/B trial as the gate's rollback; the new image as the refinement's artifact | by design: "a migration is a governed refinement, never a shell script"; no gate is wired to `stzos update` |
| **Bangalo** | the practice court: how the floor was built, one session, one human, incident-cited laws | its own doctrine lines, each paid for here (CLAUDE.md) | real: this repository is a bungalow |
| **Zing / stzp, Softanza Studio** | the projections and the visual lens over the same text | the machine as one more declared world the Studio can show | by design: the device lens is commercial and stays out of this repository |
| **stzn** | the narrator: every court speaks through it | the transcript, the verdict and the plan as pages | queued: transcripts are text today, not narrations |

The reading of the table matters more than any row: the floor adds no
language, no runtime and no product. It gives every existing tool the
one thing none of them had, a machine they can trust because it was
declared in the same way they were.

## 6. What the angle changes in the queue

None of these is ordered. They are what this analysis makes visible;
the author orders.

1. **The guarantee sheet becomes a fixture.** RestoLean's four
   guarantees should be four named expectations judged by the court
   (a transcript line for each), so that "always reachable, stable
   name, durable log, survives the cut" is a verdict, not a brochure.
   The first three already have their lines; "survives the cut" is
   the watchdog's real countdown on the board (OS-5).
2. **Egress by declaration.** DIKO's ESC6 (sensitive data never leaves
   the perimeter) is a NETWORK fact the language cannot yet state: it
   declares the interface, not whom the machine may speak to. Declared
   peers with the firewall derived from them is a fixture-first
   widening, and the seat the NGO's requirement names.
3. **The evidence page.** Sonibank's auditor reads a transcript and a
   verdict; stzn should render them as the page the audit chain
   points to.
4. **The fleet as one declaration set.** The customs school, the NGO's
   bases and the restaurant's boxes are each many machines. A set of
   `.machine` files judged together, under zin's constitution, is the
   fleet court; the per-device identity already queued (an Ed25519 key
   that never leaves the board) is its first fact.
5. **The teaching kit.** One script that declares, judges, images and
   boots a machine on a student's laptop, with the fixture file as the
   curriculum. ESPA-MT is the ground; the emulator court is the
   mechanism, already built.
6. **Keep the refusals.** No store, no shell, no package manager, no
   drift. Every one of the five solutions above is served by what the
   machine refuses, and none is served by what an ecosystem adds.

## 7. Honest boundaries

- No customer runs stzos. Three declared machines boot in emulators;
  one sensor projects onto MicroRing; no board has been flashed; the
  Makeen box's worlds are stand-ins that exit; the touch profile is a
  design.
- The kernel is borrowed and pinned, the board's firmware is a vendor
  blob pinned by digest, the compiler that builds the kernel is gcc,
  and the emulator is the court's instrument, not the product's. The
  sovereignty table in `ARCHITECTURE.md` says which is which; this
  document does not improve on it.
- "Shaped by the solution" is a claim about the mechanism, verified by
  fixtures and transcripts, not a claim that any of the five solutions
  has adopted it. Four of the five are proposals, partnerships or
  designs. One, RestoLean, has a machine file for its Commons box, a
  demo that passed on a laptop, and a board on order.
- The ecosystem has one thing the declared machine does not: the
  hardware it runs on, with local AI in the newest phones that "no
  home-made box will ever have" (B9 §5). B9's answer stands here
  unchanged: enslave the commodity device where it fits, declare the
  box where the network role justifies it, and let the posture cover
  both.
