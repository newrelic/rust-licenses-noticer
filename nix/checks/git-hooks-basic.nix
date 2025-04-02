{
  inputs,
  system,
  pkgs,
  ...
}:
inputs.git-hooks.lib.${system}.run {
  src = ../../.; # The root directory of the flake
  hooks = {
    # Rust
    cargo-check.enable = true;
    clippy = {
      enable = true;
      settings = {
        denyWarnings = true;
        allFeatures = true;
      };
    };
    rustfmt.enable = true;
    taplo.enable = true;
    # Nix
    flake-checker.enable = true;
    deadnix.enable = true;
    nixfmt-rfc-style.enable = true;
    statix.enable = true;
    # Git
    convco.enable = true;
    # Language
    vale.enable = false;
  };
  # nix flake check runs in a pure environment, so clippy and cargo don't have access to anything
  # that's not tracked by git and can't fetch dependencies from the internet.
  # This is a "workaround".
  settings.rust.check.cargoDeps = pkgs.rustPlatform.importCargoLock {
    lockFile = ../../Cargo.lock;
  };
}
