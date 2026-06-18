# Animate Lean Proofs

> **Fork note:** This is a fork of
> [dwrensha/animate-lean-proofs](https://github.com/dwrensha/animate-lean-proofs),
> updated to run on **Blender 5.x** and to provide a Nix flake dev environment
> (`nix develop`). See [AGENTS.md](./AGENTS.md) for the details of the changes.

This is a tool that accepts as input any Lean 4 theorem,
and produces as output a Blender animation showing
the steps of the proof smoothly evolving in sequence.

![example](./example.gif)

[This video](https://youtu.be/KuxFWwwlEtc) provides some more background
and shows some examples.

[<img src="http://img.youtube.com/vi/KuxFWwwlEtc/maxresdefault.jpg" height="240px">](http://youtu.be/KuxFWwwlEtc)

## more examples

|  |  |
| ----- | ---- |
| [IMO 2024 Problem 2](https://youtu.be/5IARsdn78xE) | [<img src="http://img.youtube.com/vi/5IARsdn78xE/maxresdefault.jpg" height="120px">](https://youtu.be/5IARsdn78xE)|
| [IMO 1987 Problem 4](https://youtu.be/gi8ZTjRO-xI) | [<img src="http://img.youtube.com/vi/gi8ZTjRO-xI/maxresdefault.jpg" height="120px">](https://youtu.be/gi8ZTjRO-xI)|


## setup

You need three external tools on your `PATH`:

1. [Blender](https://www.blender.org/) **5.x** (the scripts target the Blender 5.x
   Python API).
2. [Pygments](https://pygments.org/) — `HighlightSyntax.lean` shells out to its
   `pygmentize` CLI: `pip install pygments`.
3. [ffmpeg](https://ffmpeg.org/) — used to encode the rendered frames into a video.

Alternatively, `nix develop` provides Blender, pygmentize and ffmpeg pinned via
this repo's `flake.nix` (run `lake` from your host toolchain, not from inside the
nix shell — see [AGENTS.md](./AGENTS.md)).

## running

```shell
$ lake exe cache get
$ lake exe Animate Input/NNG.lean NNG.mul_pow > /tmp/mul_pow.json
# headless: render straight to a video file
$ blender -b --python animate_proof.py -- /tmp/mul_pow.json --out /tmp/mul_pow.mp4
# or, interactively: open the animation in the Blender GUI to scrub/play it
$ blender --python animate_proof.py -- /tmp/mul_pow.json
```




