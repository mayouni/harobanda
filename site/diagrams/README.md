# Drawing the site's diagrams

Diagrams 1, 2 and 3 were authored by hand, outside this repository. From
diagram 4 on they are **drawn here**, so a change to one is an edit to a
file rather than a redraw from memory.

The brief each composition answers — what sentence it must make true, its
labels, and what it must not do — is `site/DIAGRAMS.md`. This directory is
only how a brief becomes a `.jpg`.

## Running one

```
pip install Pillow
python site/diagrams/diagram4.py
```

It writes `site/harobanda-diagram-4.jpg` and prints the path. Then:

```
python site/diagrams/activate_slot.py 4
```

which uncomments that diagram's slot in the page and refuses if the image is
not on disk. Set the row in `site/DIAGRAMS.md` to **live** in the same
commit.

## What is in here

| | |
|---|---|
| `house.py` | the palette and the primitives — the house style, in code |
| `diagramN.py` | one composition, importing `house` |
| `fonts/` | IBM Plex Sans and Mono, as WOFF, under the OFL (`LICENSE-IBM-Plex.txt`) |
| `activate_slot.py` | uncomment a slot once its image exists |

The fonts are vendored because the diagrams must set type in the *same*
faces as the pages, and a diagram that silently falls back to whatever the
machine happens to have installed is a different diagram. FreeType reads
WOFF directly, so Pillow needs nothing else.

## Two things the code does on purpose

**It draws at 3× and downsamples.** Pillow anti-aliases text but not lines
or polygons, so a stroke drawn at final size has stepped edges. Everything is
laid out in logical pixels on a 1376 × 768 canvas, rendered at 4128 × 2304,
and resized with Lanczos on save.

**Every canvas is seeded.** The outlines carry a low-frequency wobble so a
drawn band sits beside the hand-authored diagrams without announcing itself —
but `canvas(n)` seeds the generator from the diagram's own number, so the
same script always produces the same file. Re-running `diagram4.py` on an
unchanged tree reproduces its `.jpg` byte for byte; if it does not, something
in `house.py` moved.

## Adding diagram N

1. Read its brief in `site/DIAGRAMS.md`.
2. Copy the shape of `diagram4.py`: `canvas(N)`, lay out in logical px,
   `save(img, "harobanda-diagram-N.jpg")`.
3. Use the palette names from `house.py`, never raw tuples — and the orange
   **once**, on the thing that matters most.
4. Keep every label readable. Inside a diagram a secondary label is
   monospace and grey; it is never shrunk to say it matters less.
5. Where the diagram shows a direction rather than a fact today, say so in
   the image.
