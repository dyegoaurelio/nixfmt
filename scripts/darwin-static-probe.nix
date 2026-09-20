# Temporary helper for `.github/workflows/darwin-static-probe.yml`.
#
# Builds the static darwin package set from one Nixpkgs, with and without the
# stale Template Haskell declarations the failure appears to be about. The
# caller picks the revision -- see `scripts/nixpkgs-sources.nix` -- so that one
# run can compare two of them. Tracks
# https://github.com/NixOS/nixfmt/issues/411; delete this file, that one, and
# the workflow once it is settled.
{
  nixpkgs,
  system ? builtins.currentSystem,
}:
let
  main = import ../main.nix { inherit system nixpkgs; };

  inherit (main) lib pkgs;
  inherit (pkgs.haskell.lib.compose) justStaticExecutables dontHaddock overrideCabal;

  staticPkgs = pkgs.pkgsStatic;
  staticHaskell = staticPkgs.haskellPackages;
  staticGhc = staticHaskell.ghc;
  buildGhc = staticHaskell.buildHaskellPackages.ghc;

  # Delete a stale `other-extensions: TemplateHaskell` declaration. Cabal reads
  # that field alone to decide a component "uses" Template Haskell, and then
  # builds it the way the compiler itself was built, on top of the wanted ways.
  # Neither component needs the declaration: pretty-simple's library has used no
  # Template Haskell since v4.0.0.0, and nixfmt's own splice compiles without it.
  dropTemplateHaskellDeclaration =
    { cabalFile, script }:
    overrideCabal (drv: {
      postPatch = (drv.postPatch or "") + ''
        echo "patching ${cabalFile}"
        sed -i ${lib.escapeShellArg script} ${cabalFile}
      '';
    });

  prettySimpleWithoutDeclaration = dropTemplateHaskellDeclaration {
    cabalFile = "pretty-simple.cabal";
    script = "/^ *other-extensions: *TemplateHaskell *$/d";
  } staticHaskell.pretty-simple;

  nixfmtWithoutDeclarations = dropTemplateHaskellDeclaration {
    cabalFile = "nixfmt.cabal";
    script = "/^ *TemplateHaskell *$/d";
  } (staticHaskell.nixfmt.override { pretty-simple = prettySimpleWithoutDeclaration; });
in
{
  # Facts we can establish without building anything expensive.
  toolchainReport = {
    nixpkgs = toString nixpkgs;
    buildPlatform = staticPkgs.stdenv.buildPlatform.config;
    hostPlatform = staticPkgs.stdenv.hostPlatform.config;
    isCross = staticPkgs.stdenv.buildPlatform != staticPkgs.stdenv.hostPlatform;
    isStatic = staticPkgs.stdenv.hostPlatform.isStatic;
    ghc = staticGhc.name;
    ghcEnableShared = staticGhc.enableShared or null;
    ghcTargetPrefix = staticGhc.targetPrefix;
    buildGhcEnableShared = buildGhc.enableShared or null;
    # Equal names are the whole problem: a bare `--with-ghc=ghc` cannot tell the
    # two compilers apart, so `PATH` order decides which one is used.
    compilersCollide = "${staticGhc.targetPrefix}ghc" == "${buildGhc.targetPrefix}ghc";
  };

  # The compiler the package set means to build with. The fix does not touch it,
  # so revisions that differ only by the fix share this build.
  ghc = staticGhc;

  pretty-simple = staticHaskell.pretty-simple;
  nixfmt-static = main.packages.nixfmt-static;

  declarations-removed = lib.pipe nixfmtWithoutDeclarations [
    justStaticExecutables
    dontHaddock
  ];
}
