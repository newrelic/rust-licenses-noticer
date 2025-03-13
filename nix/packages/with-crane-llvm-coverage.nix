{
  perSystem,
  pkgs,
  flake,
  ...
}:
let
  rustToolchain = perSystem.fenix.complete.withComponents [
    "cargo"
    "llvm-tools"
    "rustc"
  ];
  inherit (flake.lib.craneBuilder { inherit pkgs rustToolchain; }) craneLib commonArgs cargoArtifacts;
in
craneLib.cargoLlvmCov (commonArgs // { inherit cargoArtifacts; })
