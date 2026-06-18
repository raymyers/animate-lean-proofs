# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository. The same
content is surfaced to Claude Code via a thin `CLAUDE.md` that points here.

## What this project does

Turns any Lean 4 theorem into a Blender animation that shows the proof state
evolving tactic-by-tactic. The pipeline has two halves that communicate over a
single JSON document:

1. **`Animate` (Lean executable)** elaborates a proof, walks its `InfoTree`, and
   emits a `Movie` JSON describing each goal state, the tactic that transforms
   it, and per-character syntax highlighting + diff alignment.
2. **`animate_proof.py` (Blender/`bpy` script)** consumes that JSON and renders
   the animation, morphing characters between consecutive goal states.

## Build / run

```shell
lake exe cache get                                   # fetch mathlib build cache (do this first)
lake build                                           # build all libs + the Animate executable
lake exe Animate Input/NNG.lean NNG.mul_pow > /tmp/mul_pow.json
blender -b --python animate_proof.py -- /tmp/mul_pow.json --out /tmp/mul_pow.mp4
```

`-b --python … --out FILE` renders headlessly to a video. Omit `-b`/`--out` to
open the animation in the Blender GUI for interactive scrubbing instead.

`Animate` takes `FILE_PATH CONST_NAME` plus optional flags (see `parseArgs` in
`Animate.lean`): `--print-infotree`, `--print-stage1`, `--print-stage2` (dump
intermediate representations instead of/alongside the final JSON),
`--min-match-len N` (minimum run length for diff alignment), and
`--nonmatchers "chars"` (characters excluded from diff matching). These flags are
the primary way to debug the Lean side — inspect a stage rather than guessing.

There is no test suite. Validation is empirical: run a theorem from `Input/`
through both stages and inspect the JSON or the rendered output.

### Requirements

- Lean toolchain is pinned by `lean-toolchain` (`leanprover/lean4:v4.26.0`); use
  `elan`/`lake` so the pin is honored. mathlib is pinned in `lakefile.lean`.
- `pygmentize` (the Pygments CLI) must be on `PATH` — `HighlightSyntax.assign_colors`
  shells out to `pygmentize -l lean4 -f raw`. Missing it breaks stage 3.
- **Blender 5.x** (`bpy`) for rendering, plus **ffmpeg** on `PATH` for encoding the
  video. `thumbnail.py` is a separate one-off renderer.

A `flake.nix` provides all of the above (`nix develop`); it pins Blender to the
5.x series (asserts at eval time) and bundles pygmentize + ffmpeg.

> **Gotcha — run `lake` on the host, not inside `nix develop`.** The nix shell's
> `lake` re-resolves dependencies and decides the mathlib remote URL "changed",
> deleting `.lake/packages/mathlib` and re-cloning. Keep `lake` on your host
> toolchain; only borrow `pygmentize`/`blender`/`ffmpeg` from the nix shell. The
> shellHook prints this reminder.

> **Gotcha — Blender 5.x headless video output.** Blender 5.x refuses to assign
> `render.image_settings.file_format = 'FFMPEG'` in background (`-b`) mode (the
> format is filtered out of the assignable enum even though `codec_ffmpeg` is
> built in). So `animate_proof.py` renders a PNG sequence to a temp dir and muxes
> it with the `ffmpeg` CLI (`render_to_video`) rather than using Blender's
> built-in muxer.

## Architecture: the three Lean stages

Everything lives in `Animate.lean`; `processFile` drives the flow. Read it
top-to-bottom — the data structures are declared before the stages that build them.

- **Stage 1 — `extractToplevelStep` / `visitTacticInfo`.** Bottom-up walk of the
  `InfoTree` producing a `TacticStep` tree (`node`/`seq`). This is where Lean's
  tactic syntax is normalized: synthetic/no-op steps are dropped, child tactic
  text is replaced with `?_` (`replace_inner_syntax`), and the custom combinators
  from `Annotations.lean` are unwrapped. Marked `unsafe` because it uses the Lean
  interpreter frontend.
- **Stage 2 — `stage2` / `stage2_aux`.** Flattens the tree into a `StepMap`
  (`goalId → TacticStep'`): for each goal, the most specific tactic that consumes
  it. This is the lookup table stage 3 walks.
- **Stage 3 — `stage3`.** Walks goals breadth-first from the start goal, and for
  each transition computes the character-level alignment between the before/after
  goal states via `Animate.do_match` (`StringMatching.lean`) and the syntax
  coloring via `HighlightSyntax.assign_colors`. Produces the final `Movie`.

### Supporting Lean modules

- **`Annotations.lean`** defines no-op tactic combinators —
  `atomic(...)`, `reverse_s1(...)`, `reverse_s2(...)`, `reverse_s1_s2(...)`. They
  do nothing at proof time (just run the inner tactic) but are recognized by name
  in stage 1 to control how a step is animated: `atomic` collapses a block into
  one step; the `reverse_*` variants flip diff-match order (`reverse_s1`/`s2`) so
  the alignment looks natural for that tactic. Add annotations to `Input/` proofs
  to tune the animation, not to change the math.
- **`StringMatching.lean`** is the diff engine: greedy longest-common-substring
  alignment (`get_next_best_match` / `do_match`) producing `IndexMaps`
  (`s1↔s2` character index maps) that tell Blender which characters morph into
  which. Note the deliberate HACKs: the `⊢` turnstile is pinned so it never merges
  with neighbors, and hypotheses vs. goal regions are kept from matching across
  the `:`/newline boundary.
- **`HighlightSyntax.lean`** assigns a color category per character by shelling
  out to `pygmentize` and mapping Pygments token names → small ints
  (`cat_to_color`). The Python side maps those ints back to RGB.

### Python / Blender side

- **`animate_proof.py`** — main renderer. Builds the Blender scene/keyframes from
  the `Movie` JSON, then: with `--out FILE` (or in `-b` background mode) renders a
  video via `render_to_video` (PNG sequence → ffmpeg); otherwise sets up the GUI
  viewport for interactive playback. Reads env vars for config (see
  `common.envDefault`): `RENDER_ENGINE` (`WORKBENCH`/`EEVEE`/`CYCLES`), `FPS`,
  `RESOLUTION_X/Y`, `FRAME_START`, `FONTDIR`. CLI flags tune the animation:
  `--action_frame_count`, `--wait_frame_count`, `--switch_focus_frame_count`,
  `--foreground_ratio_y`, `--out`. `SYNTAX_CATS` here must stay in sync with
  `cat_to_color` in `HighlightSyntax.lean`.
- **`common.py`** — shared Blender helpers (render-engine setup, SVG import,
  camera).
- **`thumbnail.py`** — independent still/thumbnail renderer (perspective camera,
  Cycles by default).

## Inputs

`Input/*.lean` are the example theorems (IMO problems, Natural Number Game, etc.),
aggregated by `Input.lean`. These are the corpus you animate; a proof must
**not** already be in the environment (`Animate` errors if `CONST_NAME` exists),
so it elaborates the file fresh.

## Conventions worth knowing

- `lakefile.lean` sets `autoImplicit := false` and `relaxedAutoImplicit := false`
  — declare your binders explicitly.
- The Lean↔Python contract is the JSON shapes (`Movie`, `Action`, `GoalAction`,
  `TransformedGoal`, `IndexMaps`, `GoalHighlighting`). Changing a field on either
  side requires changing both.
- The frontend-elaboration code is `unsafe` by necessity; keep new `InfoTree`
  traversal inside that boundary.
