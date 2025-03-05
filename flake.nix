{
  description = "Rust License Noticer";

  inputs = {
    # The Nix package repository, for installing arbitrary dependencies
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # A Nix library for building cargo projects.
    crane.url = "github:ipetkov/crane";

    # Rust toolchains (and rust-analyzer) nightly for Nix, decoupled from nixpkgs
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      fenix,
      flake-utils,
      advisory-db,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        inherit (pkgs) lib;

        craneLib = (crane.mkLib pkgs).overrideToolchain fenix.packages.${system}.stable.toolchain;

        # Nix considers that a derivation must be rebuilt whenever any of its inputs change, including all source files passed into the build. Unfortunately, this means that changes to any "irrelevant" files (such as the project README) would end up rebuilding the project even if the final outputs don't actually care about their contents!
        # There are source filtering techniques to handle this.
        unfilteredRoot = ./.; # The original, unfiltered source
        src = lib.fileset.toSource {
          root = unfilteredRoot;
          fileset = lib.fileset.unions [
            # Default files from crane (Rust and cargo files)
            (craneLib.fileset.commonCargoSources unfilteredRoot)
            # Additional paths
            ./tests/golden/fixtures
            # Example: Also keep any markdown files
            # (lib.fileset.fileFilter (file: file.hasExt "md") unfilteredRoot)
            # Example of a folder for images, icons, etc that might not be present
            # (lib.fileset.maybeMissing ./assets)
          ];
        };

        # Common arguments can be set here to avoid repeating them later
        commonArgs = {
          inherit src;
          # Info about `strictDeps`: https://github.com/NixOS/nixpkgs/pull/354949/files
          strictDeps = true;

          buildInputs =
            [
              # Add additional build inputs here
            ]
            ++ lib.optionals pkgs.stdenv.isDarwin [
              # Additional darwin specific inputs can be set here
              pkgs.libiconv
            ];

          # Additional environment variables can be set directly
          # MY_CUSTOM_VAR = "some value";
        };

        craneLibLLvmTools = craneLib.overrideToolchain (
          fenix.packages.${system}.stable.withComponents [
            "cargo"
            "llvm-tools"
            "rustc"
          ]
        );

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Build the actual crate itself, reusing the dependency
        # artifacts from above.
        rust-licenses-noticer = craneLib.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts;
          }
        );
      in
      {
        checks = {
          # Build the crate as part of `nix flake check` for convenience
          inherit rust-licenses-noticer;

          # Run clippy (and deny all warnings) on the crate source,
          # again, reusing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          rust-licenses-noticer-clippy = craneLib.cargoClippy (
            commonArgs
            // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          rust-licenses-noticer-doc = craneLib.cargoDoc (
            commonArgs
            // {
              inherit cargoArtifacts;
            }
          );

          # Check formatting
          rust-licenses-noticer-fmt = craneLib.cargoFmt {
            inherit src;
          };

          rust-licenses-noticer-toml-fmt = craneLib.taploFmt {
            src = pkgs.lib.sources.sourceFilesBySuffices src [ ".toml" ];
            # taplo arguments can be further customized below as needed
            # taploExtraArgs = "--config ./taplo.toml";
          };

          # Audit dependencies
          rust-licenses-noticer-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };

          # Audit licenses
          rust-licenses-noticer-deny = craneLib.cargoDeny {
            inherit src;
          };

          # Run tests with cargo-nextest
          # Consider setting `doCheck = false` on `my-crate` if you do not want
          # the tests to run twice
          rust-licenses-noticer-nextest = craneLib.cargoNextest (
            commonArgs
            // {
              inherit cargoArtifacts;
              partitions = 1;
              partitionType = "count";
              cargoNextestPartitionsExtraArgs = "--no-tests=pass";
            }
          );
        };

        packages =
          {
            default = rust-licenses-noticer;
          }
          // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
            my-crate-llvm-coverage = craneLibLLvmTools.cargoLlvmCov (
              commonArgs
              // {
                inherit cargoArtifacts;
              }
            );
          };

        # Run the flake directly from anywhere with `nix run github:newrelic/rust-licenses-noticer`,
        # and don't worry about installing `cargo-deny`! (nor `git`... but you have that, do you?)
        apps.default = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "third-party-licenses-check" ''
            set -euo pipefail

            LICENSES=$(${pkgs.cargo-deny}/bin/cargo-deny --all-features --log-level off --manifest-path Cargo.toml list -l crate -f json)
            echo $LICENSES

            ${rust-licenses-noticer}/bin/rust-licenses-noticer --dependencies "$LICENSES" --output-file "THIRD_PARTY_NOTICES.md" --template-file "THIRD_PARTY_NOTICES.md.tmpl"

            STATUS=$(${pkgs.git}/bin/git status --porcelain --untracked-files=all -- "THIRD_PARTY_NOTICES.md")

            if [[ "$STATUS" =~ ^"??" ]]; then
              echo "Notices file was created!"
              exit 1
            elif [[ "$STATUS" =~ ^" M" ]]; then
              echo "Notices file was modified!"
              exit 1
            else
              echo "Notices file is up to date."
            fi
          '';
        };

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};

          # Additional dev-shell environment variables can be set directly
          # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

          # Extra inputs can be added here; cargo and rustc are provided by default.
          packages = [
            # pkgs.ripgrep
          ];
        };
      }
    );
}
