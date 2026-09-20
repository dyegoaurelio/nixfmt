# The two Nixpkgs revisions `scripts/darwin-static-probe.nix` compares: this
# repository's `flake.lock` pin, and that pin plus the fix. Pinned to revisions
# rather than branches so a run says exactly what it built.
#
# The pin is used rather than `haskell-updates` because everything here but the
# fix itself is in cache.nixos.org. On `haskell-updates` nothing is, and a run
# has to build three compilers from source -- the bootstrap, the static target,
# and the native one that every package takes as a `depsBuildBuild` dependency
# -- which does not fit in a job.
#
# Temporary, like the probe itself.
{
  baseline = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/aff8a0b28396750446e5537a96461bc4facdb287.tar.gz";
  };

  # The same revision plus the fix, from the `fix/haskell-static-ghc-by-path`
  # branch. The change is identical to the one proposed upstream; only its
  # comment wording differs, which Nix discards.
  patched = builtins.fetchTarball {
    url = "https://github.com/dyegoaurelio/nixpkgs/archive/6e00f0272e6ac0023340ece8ed8e32c1bfef9f8c.tar.gz";
  };
}
