# Site diagrams — the register and the briefs

Working document for `site/`. Not linked from any page, not deployed content.

## The rule

> **A diagram earns its place only where prose cannot go: containment, flow
> over time, derivation, topology.** Comparison, enumeration and ranking
> already have devices here — `.cmp`, `.trio`, `.refuses`, `.versus`,
> `.osdelta`. Drawing those again is decoration.

> **A page's thesis image goes in its first third, or it is a souvenir
> rather than a frame.** A page over ~4 screens earns a second at the
> payoff point (~75%), where the reader has earned the detail.

Measured before this register existed: three diagrams across seven pages,
both of the non-AI ones below 78% depth, and 63% of the site's 34.5 screens
carrying no diagram at all.

## House style — derived from diagrams 1–3, match it

| | |
|---|---|
| **size** | 1376 × 768 (16:9), JPEG. A shorter canvas only when the page demands it — diagram 9 is 1376 × 500 because it sits above the front page's card row and must not tower over it. Set the `height` attribute in the slot to match, or the page reserves the wrong box |
| **canvas** | warm cream `#f5efe1` — the diagram's own ground, *not* the page background `#e8e8e3`; the border comes from CSS |
| **ink** | dark navy `#283347` for titles and primary labels |
| **the machine** | blue-grey fill `#8a9ba5`–`#b4bfc1`, heavier dark stroke — Harobanda is always the emphasised box |
| **accent** | warm orange `#f09d7b` — used *once* per diagram, on the thing that matters most |
| **neutrals** | `#e3dfd4`, `#deddd8`, `#d1c9bc` taupe, `#c2cece` pale blue-grey |
| **refusal** | brick red, only for a crossed path or a NOT KEPT |
| **shapes** | rounded rectangles with a slightly rough, hand-drawn stroke |
| **type** | IBM Plex Sans and Mono, vendored in `diagrams/fonts/`. One readable size — `READ = 32` — for **everything** a reader reads, mono or sans. `TITLE = 40` for a primary label, `KICKER = 26` letterspaced for an uppercase tag. A code block may sit below `READ`; nothing else may |
| **connectors** | thin grey elbow lines, no heavy arrowheads |
| **icons** | small, single-weight line icons, right-aligned inside a band |

Two standing constraints, both from the site's own doctrine:

- **No small text to signal lesser importance, and the rule does not stop at
  the edge of a picture.** A secondary label is told apart by font, weight and
  colour — monospace and grey against sans and dark — never by being set
  smaller. This was measured, not assumed: the page renders a diagram 952px
  wide, so image pixels shrink by 0.69 before anyone reads them, and in
  diagrams 1–3 both titles and sub-labels land at 19–22px on screen. The
  first cut of diagrams 4–7 ran at roughly half that and shrank its
  sub-labels below its titles; all four were refit. `house.fit()` now refuses
  to render a label wider than its box, so the pressure of a bigger type size
  falls on the wording, where it belongs.
- **Claim only what is true.** Where a diagram shows something that is a
  direction rather than a fact today, it must say so in the image, the way
  `harb learn 18` prints the honest number.

## Register

| # | file | page | slot | status |
|---|---|---|---|---|
| 1 | `harobanda-diagram-1.jpg` | why | opens the page, 10% | **live** |
| 2 | `harobanda-diagram-2.jpg` | ai | frames the stack section, 22% | **live** |
| 3 | `harobanda-diagram-3.jpg` | ai | pays off the example, 78% | **live** |
| 4 | `harobanda-diagram-4.jpg` | machine | *not a new kernel*, 15% | **live** |
| 5 | `harobanda-diagram-5.jpg` | machine | *survives the cut*, 48% | **live** |
| 6 | `harobanda-diagram-6.jpg` | build | opens the page, 11% | **live** |
| 7 | `harobanda-diagram-7.jpg` | why | *difference one*, 46% | **live** |
| 8 | `harobanda-diagram-8.jpg` | enterprise | before the three cards, 35% | **live** |
| 9 | `harobanda-diagram-9.jpg` | index | *what just happened*, 31% | **live** (1376 × 500) |
| 10 | `harobanda-diagram-10.jpg` | field | before the two cases, 40% | slot placed |

Depths are measured in the browser at 1380 × 900, not estimated. They shift
downwards a few points as each image lands and the page grows — an image is
roughly 530 px tall at the 1080 px measure, so one of them adds about a tenth
to a six-screen page. The first diagram on a page must stay in the first third.

Each slot is already marked in the HTML with a comment carrying the exact
`<img>` tag. Drop the file into `site/`, uncomment the tag, done:

```
grep -rn "DIAGRAM SLOT" site/*.html
```

---

## 4 · What was kept, what was replaced — `machine.html`

**Highest value on the site.** The page currently runs four paragraphs of
pure prose before anything visual at 33%, and this is the image that answers
the first objection an IT reader has.

**The sentence it must make true:** *the kernel is the same one you already
run; everything the industry treats as inevitable above it is gone, replaced
by one idea.*

**Composition.** Two stacks side by side, same width, same baseline.

- Left, headed `AN ORDINARY DISTRIBUTION` — a tall pile of bands, visibly
  crowded: `a shell`, `a package manager`, `a service manager`, `mutable
  configuration`, `a login · an account`, `a store`. Neutral greys. The
  crowding is the point.
- Right, headed `HAROBANDA` — two bands only, generous space: **`the
  declaration`** and **`the court`**, in the machine's blue-grey, the
  declaration carrying the single orange accent.
- **Beneath both, one band spanning the full width, identical on both
  sides**, drawn as continuous through the divider: `Linux LTS — the same
  kernel, the same drivers, the same decades of hardening`. This band must
  read as *shared*, not as two matching bands.
- A hairline vertical divider between the stacks, ending where the shared
  band begins.

**Exact labels.** Title strip: `THE KERNEL IS THE SAME. EVERYTHING ABOVE IT
IS NOT.` Under the right stack, monospace: `declare it · judge it · govern
it`. Under the left, monospace grey: `convention, not the kernel's doing`.

**Must not.** No version numbers, no distro names, no logos. Do not imply the
kernel is modified — it is pinned source rebuilt by your own toolchain, and
the whole point is that it is untouched.

---

## 5 · The trial — `machine.html`

Flow over time. Currently one row of a table: the most concrete mechanism on
the site, rendered as a sentence.

**The sentence it must make true:** *a new version is tried once, and if it
does not recognise its own boot the board returns to the one that worked —
with nobody on site.*

**Composition.** A left-to-right timeline, five beats, the two slots drawn as
two horizontal lanes running the whole width.

1. `slot A` lane filled and live, labelled `running`; `slot B` lane empty.
2. The new image written into `slot B` — arrow down into the lane.
3. `slot B` boots **as a trial** — the emphasised beat, orange accent, with a
   small hardware-timer glyph beside it labelled `the watchdog is armed`.
4. The fork, drawn as two outcomes from the same point:
   - **up** — `the boot matches its declaration` → `COMMIT` → `slot B` lane
     becomes the live one, in the machine's blue-grey.
   - **down** — `it does not` → the watchdog is never fed → `RESET` → an arrow
     curving back to `slot A`, still filled, still exactly as it was, in
     brick red.
5. A closing strip.

**Exact labels.** Title strip: `TWO SLOTS, A TRIAL, AND A TIMER THAT IS NOT
SOFTWARE.` Closing strip, monospace: `a verdict that does not reach the exit
code only convicts someone who is watching`. Beside the down path:
`no one drives out to fix it`.

**Must not.** Do not draw a person, a console or a dashboard — the mechanism's
whole claim is that nobody is there. Do not label the watchdog "automatic
recovery"; it is a hardware timer that stops being fed.

---

## 6 · One file, four devices — `build.html`

This is already a heading on the page — *"The same file, projected to four
kinds of device"* — rendered as four text cards at 74% depth. It is
inherently a diagram and is being wasted there. The image opens the page; the
cards stay as its detail.

**The sentence it must make true:** *you change one word and re-derive; you do
not learn a new toolchain per device.*

**Composition.** One `.machine` file at the left or centre, drawn as a
document with a few visible declaration lines, in the machine's blue-grey.
Four elbow connectors fanning out to four device silhouettes:

| device | label | sub-label (mono) |
|---|---|---|
| a tower / PC | `a normal PC` | `x86_64 · hosted shape` |
| a Raspberry Pi board | `a Raspberry Pi` | `arm64 · two slots` |
| a tablet | `a tablet or phone` | `touch shape · design` |
| a small MCU | `a sensor or MCU` | `edge shape · no kernel at all` |

Along the fan, the single orange accent on a callout reading **`one word
changes: the board`**. Along the bottom, a mono strip listing what does not
change: `harb check · harb plan · harb boot — the same command, every target`.

**Must not.** Do not draw four files. Do not show a build pipeline, a CI
system or a cloud — the claim is one binary on one laptop. Mark the touch
shape as `design` in the image, since it is not a fact today.

---

## 7 · Derived, not adapted — `why.html`

Difference one is the page's central claim and has only a bullet-vs-bullet
table. This is a *derivation* — direction of causation — which is precisely
what prose and two columns cannot show.

**The sentence it must make true:** *you do not bend the solution to fit the
OS; the machine is derived from what the solution must guarantee.*

**Composition.** Two panels, and the arrows between them must point in
**opposite directions** — that opposition is the entire diagram.

- **Left, `A GENERAL-PURPOSE OS`.** A large box crowded with everything,
  labelled `built for everyone`. An arrow points **from your solution into
  it**, labelled `you adapt, and subtract`, with a small cluster of crossed-out
  items falling away — and a grey note: `what you did not remove is still
  there`.
- **Right, `A DECLARED MACHINE`.** At the top, a sheet titled `what the job
  must guarantee`, listing four promises in monospace: `a fixed address`, `a
  name that never moves`, `a record that survives`, `a clean restart`. One
  broad arrow points **down** from the sheet, labelled **`DERIVE`** in the
  orange accent, into a machine box that is visibly *smaller* and contains
  exactly four matching items and nothing else.

**Exact labels.** Title strip: `ONE IS ADAPTED DOWNWARDS. THE OTHER IS DERIVED
UPWARDS FROM THE JOB.` Under the right machine, monospace: `contains only what
was declared — nothing more`.

**Must not.** Do not make the declared machine look impoverished; make it look
*exact*. The left box should read as crowded, not as powerful.

---

## 8 · The fleet, and the cloud beside it — `enterprise.html`

The thinnest page on the site — 2.2 screens with a single row of cards — and
the page where one sentence is most often misread.

**The sentence it must make true:** *sovereign nodes that integrate with the
cloud you already run — not a cloud replacement, and not a cloud dependency.*

**Composition.** Two halves of one picture.

- **Left, the fleet.** One declaration file at the top, in blue-grey. Arrows
  down to three or four identical boxes in a row, each drawn the same,
  labelled `derived from one file · bit-for-bit`. Each box carries a small key
  glyph and its own short fingerprint in monospace (`KEY1`, `KEY2`, `KEY3` —
  distinct, never the same value). Under them a mono strip: `no snowflakes ·
  scale adds no configuration entropy`.
- **Right, the cloud — drawn at the same altitude, never above.** A cloud
  shape connected to the fleet by a horizontal line labelled `declared reach ·
  synced on your terms`, with a small note: `the same declared machine can run
  in the cloud too`.
- The verification claim, as a short aside: a figure holding only the **public**
  half checks a box's record, with the line `checked by someone who never held
  the secret`.

**Exact labels.** Title strip: `A FLEET IS A SET OF DECLARATIONS.` The
horizontal cloud link must be visually a *peer link*, same weight both ways.

**Must not.** Never draw the cloud above the boxes or as a hub they hang from —
that is the exact misreading this diagram exists to prevent. Do not show a
management console.

---

## 9 · The loop — `index.html`

The four cards on the front page are a sequence; the method is a **circle** —
the boot is judged against the file, and the file against the boot. Cards
cannot show that they close.

**The sentence it must make true:** *the last step returns to the first; that
closure is the whole method.*

**Composition.** A ring of five beats, read clockwise, with the return arrow
drawn as heavily as the rest:

`declare` → `judge — harb check` → `plan — harb plan` → `boot — harb boot` →
`it judges its own boot` → back to `declare`.

The closing arrow carries the orange accent and the label **`a change is a new
file, judged again`**. In the centre of the ring, the `.machine` file itself,
small, in blue-grey. Beside the `judge` beat, a small refusal glyph with a
mono example: `needs the network, which nothing here grants.`

**Must not.** No numbered 01–04 badges — the cards below already carry those,
and repeating them makes the diagram a restatement instead of an addition.
Keep it small and wide; this sits above a card row and must not dominate the
front page.

---

## 10 · The two deployments — `field.html`

The page whose job is to be concrete has nothing visual until 45%. Topology
makes a case real rather than claimed.

**The sentence it must make true:** *one a critical application, one a critical
agent — and both the same floor.*

**Composition.** Two topologies side by side, each labelled with its place, a
thin divider between them.

- **Left, `COUSBOX · a restaurant in Lyon`.** One box behind the counter, in
  the machine's blue-grey, at the centre. Around it: a customer's phone
  (`ordering`), a kitchen display, a till. All connections local and drawn
  short. A crossed link to the internet labelled `the service does not stop
  when the link does`. Status chip, monospace: `app delivered · box on
  Harobanda`.
- **Right, `DIKO · an NGO in Niger`.** A hub in Niamey and two bases,
  `Gothèye` and `Diffa`, joined to it. Each site drawn as the same declared
  box. Between them, a sync line labelled `local-first · syncs on declared
  terms`. Inside the hub, a small agent glyph inside an envelope outline,
  labelled `confined · every action recorded`. Status chip: `won · in
  development`.

**Exact labels.** Title strip: `TWO PLACES, ONE FLOOR.` Keep the two status
chips honest and visibly different — one delivered, one in development.

**Must not.** Do not draw a datacentre, a logo, or a map of Africa. Do not
make the two look like one product with two skins; they are two topologies
that happen to share a floor.

---

## After an image lands

Diagrams 1–3 were authored by hand outside this repository. From 4 on they
are drawn by a script in `site/diagrams/`, so a change is an edit rather
than a redraw — see `site/diagrams/README.md`.

```
python site/diagrams/diagram4.py          # writes site/harobanda-diagram-4.jpg
python site/diagrams/activate_slot.py 4   # uncomments its slot, refuses if absent
```

Then set the row in the register above to **live**, in the same commit, and
check it: the page's first diagram must sit in the first third.

```
grep -rn "DIAGRAM SLOT" site/*.html
```
