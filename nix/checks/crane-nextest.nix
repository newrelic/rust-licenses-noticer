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
craneLib.cargoNextest (
  commonArgs
  // {
    inherit cargoArtifacts;
    partitions = 1;
    partitionType = "count";
    cargoNextestPartitionsExtraArgs = "--no-tests=pass";
  }
)
