{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # An opinionated "framework" to standardize the folder structure for Nix flake projects
    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # A collection of Git hooks for all kinds of projects.
    # Suitable for adding into devshells!
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # A Nix library for building cargo projects.
    crane.url = "github:ipetkov/crane";

    # Rust toolchains (and rust-analyzer) nightly for Nix, decoupled from nixpkgs
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };

    # Rust security advisory database
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };

    # Define devshells with TOML
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      prefix = "nix";
    };
}
