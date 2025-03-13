{
  flake,
  perSystem,
  pkgs,
  ...
}:
let
  rustToolchain = perSystem.fenix.stable.toolchain;
  inherit (flake.lib.craneBuilder { inherit pkgs rustToolchain; }) craneLib src;
in
craneLib.taploFmt {
  src = pkgs.lib.sources.sourceFilesBySuffices src [ ".toml" ];
  # taplo arguments can be further customized below as needed
  # taploExtraArgs = "--config ./taplo.toml";
}
