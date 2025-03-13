{
  perSystem,
  system,
  flake,
  inputs,
  ...
}:
let
  crossSystem = "aarch64-unknown-linux-musl";
  pkgs = import inputs.nixpkgs {
    inherit crossSystem;
    localSystem = system;
  };
  rustToolchain =
    _p:
    with perSystem.fenix;
    combine [
      stable.cargo
      stable.rustc
      targets.${crossSystem}.stable.rust-std
    ];
  inherit (flake.lib.craneBuilder { inherit pkgs rustToolchain; }) craneLib commonArgs cargoArtifacts;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;
    CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
  }
  // craneLib.mkCrossToolchainEnv (p: p.clangStdenv)
)
