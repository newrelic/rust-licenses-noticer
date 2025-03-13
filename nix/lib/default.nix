{ inputs, ... }:
{
  craneBuilder =
    {
      pkgs,
      rustToolchain ? null,
    }:
    let
      inherit (pkgs) lib;
      # Define the craneLib variable, which provides a library for building Rust projects.
      # If a specific Rust toolchain is provided, it overrides the default toolchain with it.
      craneLib =
        if builtins.isNull rustToolchain then
          inputs.crane.mkLib pkgs
        else
          (inputs.crane.mkLib pkgs).overrideToolchain rustToolchain;
      # Nix considers that a derivation must be rebuilt whenever any of its inputs change,
      # including all source files passed into the build.
      # Unfortunately, this means that changes to any "irrelevant" files (such as the project README)
      # would end up rebuilding the project even if the outputs don't even care about their contents!
      # There are source filtering techniques to handle this.
      unfilteredRoot = ../../.; # The original, unfiltered source
      src = lib.fileset.toSource {
        root = unfilteredRoot;
        fileset = lib.fileset.unions [
          # Default files from crane (Rust and cargo files)
          (craneLib.fileset.commonCargoSources unfilteredRoot)
          # Additional paths
          ../../tests/golden/fixtures
          # Example: Also keep any markdown files
          # (lib.fileset.fileFilter (file: file.hasExt "md") unfilteredRoot)
          # Example of a folder for images, icons, etc that might not be present
          # (lib.fileset.maybeMissing ./assets)
        ];
      };
      # Common arguments can be set here to avoid repeating them later
      commonArgs = {
        inherit src;
        # Info about `strictDeps` at <https://github.com/NixOS/nixpkgs/pull/354949/files>
        strictDeps = true;

        buildInputs =
          [
            # Add additional build inputs here
            pkgs.hello
          ]
          ++ lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];

        # Additional environment variables can be set directly
        # MY_CUSTOM_VAR = "some value";
      };
    in
    {
      inherit craneLib commonArgs src;
      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
    };
}
