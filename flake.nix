{
  description = "Animate Lean Proofs — Lean 4 + Blender dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        # Pin Blender to the 5.x series. animate_proof.py targets the Blender 5.x
        # API (e.g. it renders a PNG sequence + ffmpeg rather than the FFMPEG
        # file_format, which 5.x rejects in background mode). The exact build is
        # pinned by flake.lock; this assert guards against drifting off 5.x.
        blender = assert lib.assertMsg (lib.versionAtLeast pkgs.blender.version "5"
          && lib.versionOlder pkgs.blender.version "6")
          "expected Blender 5.x, got ${pkgs.blender.version}; update flake.lock or this pin";
          pkgs.blender;

        # Pygments provides the `pygmentize` CLI that HighlightSyntax.lean shells
        # out to (`pygmentize -l lean4 -f raw`).
        python = pkgs.python3.withPackages (ps: [ ps.pygments ]);
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            # `elan` manages the Lean toolchain; it reads `lean-toolchain`
            # (leanprover/lean4:v4.26.0) and provides `lean` and `lake`.
            pkgs.elan
            python
            blender
            pkgs.ffmpeg # muxes the rendered PNG frames into a video
          ];

          shellHook = ''
            echo "animate-lean-proofs dev shell (Blender ${blender.version})"
            echo "  lean:       $(lean --version 2>/dev/null || echo 'run: elan toolchain install')"
            echo "  pygmentize: $(command -v pygmentize || echo MISSING)"
            echo "  blender:    $(command -v blender || echo MISSING)"
            echo "  ffmpeg:     $(command -v ffmpeg || echo MISSING)"
            echo
            echo "  NOTE: run 'lake' on the host toolchain, not inside this shell —"
            echo "        lake re-resolves deps here and re-clones mathlib. Only"
            echo "        pygmentize/blender/ffmpeg need this shell."
            echo
            echo "  lake exe cache get   # first, fetch mathlib cache (host shell)"
            echo "  lake build           # (host shell)"
            echo "  lake exe Animate Input/NNG.lean NNG.mul_pow > /tmp/mul_pow.json"
            echo "  blender -b --python animate_proof.py -- /tmp/mul_pow.json --out /tmp/mul_pow.mp4"
          '';
        };
      });
}
