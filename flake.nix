{
  /*
    Hello, Nix! Hello, Flakes!

    This file is the definition of a Nix flake. In general, a directory, repository, or project
    containing a `flake.nix` is considered to be "a flake".

    A flake is a self-contained, reproducible, and versioned package of software
    that can be used to build, run, or develop applications.
  */
  description = "Rust Licenses Noticer";

  /*
    Flakes can define inputs, which are the dependencies for the project.
    Normally the inputs are flakes as well, but they can be any Nix expressions or
    just arbitrary sources of data.

    Any external dependencies that are not specified here are effectively "invisible" when building.
    This is a key feature of Nix and flakes, as it allows for reproducible builds
    with pinned dependency versions.

    What about the contents of the "flake directory" itself? Are these "an input"?
    If this directory is a git repository, its contents are also available to the flake
    and anything not tracked by git will be invisible.

    If we reference the flake as a path at the time of using it, then all the contents
    of the directory will be considered part of the flake.

    Let's see what our inputs are:
  */
  inputs = {
    # (BTW, one-line comments start with `#`!)
    /*
      The Nix package repository, for installing arbitrary dependencies.
      Think of it as the package repository for Nix, the same way
      the Homebrew formulae repositories are for Homebrew or apt repos for Debian
    */
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Git hooks! Uniform lints and checks for all contributors
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      /*
        Make the git-hooks flake use the same `nixpkgs` input that we have defined.

        If we don't do this, the flake will pick its own `nixpkgs` input, which means we have pulled
        in two different versions of `nixpkgs`. We might want this, or we might want to save space!
      */
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  /*
    Of course, flakes expose outputs
    This is the way other flakes can use our flake as an input, and the way we as users can
    build, run, or develop our application.

    Hermetic builds with only the inputs we need: outputs are, naturally, a function of the inputs!

    Functions in Nix take the form `arg: returned_expression`, and can pattern match like in Rust.
    In the case below, `arg` is an attribute set (i.e. a dictionary) that contains the inputs
    that we have defined above.
  */
  outputs =
    {
      self, # The flake outputs themselves!
      nixpkgs,
      git-hooks,
      ... # don't capture any additional inputs
    }:
    # Local binding of values
    let
      # What systems do we support in our flake? Will be important later
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      /*
        The function below means that, for each output that I define in the passed closure,
        I will get a separate output for each system in `supportedSystems`.

        There are "frameworks" that simplify this, but of course they'd need to be flake inputs.
        I wanted to keep the inputs simple for now.

        Signature of genAttrs: [ String ] -> (String -> Any) -> AttrSet
      */
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      /*
        The `devShells` are environments that get activated when we call `nix develop <FLAKE_REF>`.

        This is useful for declaratively defining dependencies required to build a project.
        Our use case!

        A devShell is also a Nix derivation (i.e. a package definition) with some extra attributes.
        This means it can be cached to avoid rebuilds. We will see packages later.
      */
      devShells = forAllSystems (
        system:
        let
          # The nixpkgs input set to the system we are building for
          pkgs = import nixpkgs { inherit system; };
          # We will see how we defined these git hooks later!
          gitHooks = self.checks.${system}.pre-commit-check;
        in
        {
          # A basic shell with the Rust toolchain. Ideal for development!
          basic = pkgs.mkShell {
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
          };

          # Now imagine a shell for infra actions on aws
          infra-actions = pkgs.mkShell {
            packages = with pkgs; [
              awscli
            ];
          };

          # This one auto-installs the git hooks when we enter the shell.
          withGitHooks = pkgs.mkShell {
            # The following line is equivalent to `shellHook = gitHooks.shellHook`
            # Auto-installs the hooks when we enter the shell.
            inherit (gitHooks) shellHook;

            packages = [
              # Imagine we need this to build our project
              pkgs.just
              # This one is a bit of a trick.
              # By bringing the packages used by the git hooks, which use cargo, clippy, etc,
              # we effectively bring the Rust toolchain.
              gitHooks.enabledPackages
            ];

            # We can define environment variables!
            AWS_PROFILE = "my-aws-profile";
          };

          # Setting the default shell to the one with git hooks, so when we call `nix develop`
          # it will automatically install enter that shell.
          default = self.devShells.${system}.withGitHooks;
        }
      );

      /*
        Flake checks are mainly executed when one runs `nix flake check`.
        Default behavior is to check the flake against the default schema and emit warnings
        if non-standard outputs are found or the outputs are not what they are supposed to be.

        Checks are also derivations (i.e. packages) and it’s possible to define custom ones.
        To that end they can be used as integration tests.
      */
      checks = forAllSystems (system: {
        /*
          We can define here how to run some pre-commit hooks, thanks to the git-hooks input.
          Here they are defined as a package, but of course we can add these to our development
          shell. We will see how this is done later.

          Note how we reference the `system` argument that we passed to the function.
          For each system we had specified, this will generate a separate output that calls
          the git-hooks' `run` specific to it.
        */
        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixfmt-rfc-style.enable = true; # Format nix files
            convco.enable = true; # Enforce conventional commit messages
            markdownlint = {
              enable = false; # Markdown
              excludes = [
                # This file does not follow the default rules
                # But we don't want to change it as it's a "golden" test file
                "tests/golden/fixtures/expected_third_party_notices_file\\.md"
              ];
            };
            actionlint = {
              # GH Actions
              enable = true;
              excludes = [
                # Comes from the NR template so we disregard it
                "\\.github/workflows/repolinter\\.yml"
              ];
            };

            # Rust-related checks
            cargo-check.enable = true;
            clippy = {
              enable = true;
              settings = {
                denyWarnings = true;
                allFeatures = true;
              };
            };
            rustfmt.enable = true;
            taplo.enable = true; # TOML fmt

            # A custom check!
            third-party-notices = {
              enable = true;
              name = "Third party notices file sync";
              entry = "third-party-licenses-check";
              pass_filenames = false;
              extraPackages = [
                # This is the package that will be used to generate the notices file.
                # Our own package!
                # Note how we use `self` to refer to our own flake outputs for the current system.
                self.packages.${system}.run-license-check
              ];
            };
          };
          /*
            Why do we need the following lines?

            `nix flake check` runs in a pure environment, so `clippy` and `cargo` don't have access
            to anything that's not tracked by git and can't fetch dependencies from the internet.

            If we didn't have this, we could still trigger the checks from a development shell.
            We'll see how later.
          */
          settings.rust.check.cargoDeps =
            let
              pkgs = import nixpkgs { inherit system; }; # Locally bind nixpkgs to pkgs
            in
            pkgs.rustPlatform.importCargoLock {
              lockFile = ./Cargo.lock;
            };
        };
      });

      /*
        Meaty part! Defining packages with Nix

        Packages are the most common output of a flake. Each one of the packages us what Nix calls
        a "derivation". A derivation is a recipe for building a package.
      */
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Our actual Rust project! Nixpkgs includes some helpers to build simple Rust projects.
          rust-licenses-noticer = pkgs.rustPlatform.buildRustPackage {
            pname = "rust-licenses-noticer";
            version = "0.1.0";
            src = ./.;

            # Explicit dependencies to the build!
            nativeBuildInputs =
              with pkgs;
              [
                hello # We don't need this to build our Rust project, but imagine we do!
              ]
              # We can add optional dependencies based on the system
              ++ lib.optionals stdenv.isDarwin [
                libiconv
              ];

            cargoLock.lockFile = ./Cargo.lock;
          };

          /*
            Ok, we defined our Rust package above. This is just the binary, but
            that binary still needs to run alongside `cargo-deny` to retrieve the dependency list
            of some random Rust project, do a comparison with `git` to see if it was modified, etc.

            Can we encode all of this as another package in Nix? OF COURSE!

            Let's define a script that automates the whole process of using `rust-licenses-noticer`.
            With Nix, we can capture ALL THE RUNTIME DEPENDENCIES so we are sure they're present
            during execution.

            We don't actually require using some other helper, but let's do a bit of a showoff and
            use `writeShellApplication` for this.

            Ref: <https://nixos.org/manual/nixpkgs/stable/#trivial-builder-writeShellApplication>
          */
          run-license-check = pkgs.writeShellApplication {
            name = "third-party-licenses-check";

            # Nix will make sure these are prepended to the PATH
            runtimeInputs = with pkgs; [
              cargo
              cargo-deny
              git
              # Our Rust package we just defined!
              self.packages.${system}.rust-licenses-noticer
            ];

            # The text of the script. It will automatically add the shebang line, `set -euo pipefail`,
            # and when building it will pass `shellcheck` to lint it.
            text = ''
              for i in "$@"; do
                case $i in
                  --help)
                    echo "Usage: $0 [--help] [--project-root] [--output-file <file>] [--template-file <file>]"
                    exit 0
                    ;;
                  --cargo-root=*)
                    # This is the path to the project root. We will use it to find the Cargo.toml file.
                    CARGO_ROOT="''${i#*=}"
                    shift
                    ;;
                  --output-file=*)
                    # This is the path to the output file. We will use it to write the notices.
                    OUTPUT_FILE="''${i#*=}"
                    shift
                    ;;
                  --template-file=*)
                    # This is the path to the template file. We will use it to write the notices.
                    TEMPLATE_FILE="''${i#*=}"
                    shift
                    ;;
                  --print-licenses)
                    PRINT_LICENSES=YES
                    shift
                    ;;
                  *)
                    ;;
                esac
              done

              # Set variables in case they were not defined
              WORKING_DIR=$(pwd)
              CARGO_ROOT="''${CARGO_ROOT:-$WORKING_DIR}"
              OUTPUT_FILE="''${OUTPUT_FILE:-$WORKING_DIR/THIRD_PARTY_NOTICES.md}"
              TEMPLATE_FILE="''${TEMPLATE_FILE:-$WORKING_DIR/THIRD_PARTY_NOTICES.md.tmpl}"
              PRINT_LICENSES="''${PRINT_LICENSES:-NO}"

              echo "Cargo project root: $CARGO_ROOT"
              echo "Output file: $OUTPUT_FILE"
              echo "Template file: $TEMPLATE_FILE"
              echo "Print licenses: $PRINT_LICENSES"

              LICENSES=$(cargo deny --all-features --manifest-path "$CARGO_ROOT/Cargo.toml" list -l crate -f json)

              if [[ "$PRINT_LICENSES" == "YES" ]]; then
                echo "Licenses: $LICENSES"
              fi

              rust-licenses-noticer --dependencies "$LICENSES" --output-file "$OUTPUT_FILE" --template-file "$TEMPLATE_FILE"
              STATUS=$(git status --porcelain --untracked-files=all -- "$OUTPUT_FILE")

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

          # Finally, our last package. We just set one of our existing packages as the default
          # for the flake, so when we run `nix build` or `nix run` it will be chosen automatically.
          default = self.packages.${system}.run-license-check;
        }
      );

    };
}
