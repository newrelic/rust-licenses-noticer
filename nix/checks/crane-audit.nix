{
  flake,
  perSystem,
  pkgs,
  inputs,
  ...
}:
let
  rustToolchain = perSystem.fenix.stable.toolchain;
  inherit (flake.lib.craneBuilder { inherit pkgs rustToolchain; }) craneLib src;
in
craneLib.cargoAudit {
  inherit src;
  inherit (inputs) advisory-db;
}
