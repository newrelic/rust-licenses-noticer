{
  flake,
  perSystem,
  pkgs,
  ...
}:
let
  rustToolchain = perSystem.fenix.stable.toolchain;
  inherit (flake.lib.craneBuilder { inherit pkgs rustToolchain; }) craneLib commonArgs cargoArtifacts;
in
craneLib.cargoClippy (
  commonArgs
  // {
    inherit cargoArtifacts;
    cargoClippyExtraArgs = "--all-targets -- --deny warnings";
  }
)
