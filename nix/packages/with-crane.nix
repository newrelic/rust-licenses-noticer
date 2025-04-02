{
  perSystem,
  pkgs,
  flake,
  ...
}:
let
  rustToolchain = perSystem.fenix.stable.toolchain;
  inherit (flake.lib.craneBuilder { inherit pkgs rustToolchain; }) craneLib commonArgs cargoArtifacts;
in
craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; })
