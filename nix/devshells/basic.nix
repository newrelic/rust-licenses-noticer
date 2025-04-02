{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    # The Rust toolchain
    cargo
    rustc
    clippy
    rustfmt

    # Completely run our project from this shell
    git
    cargo-deny
  ];
}
