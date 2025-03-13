{
  flake,
  perSystem,
  pkgs,
  ...
}:
let
  rustToolchain = perSystem.fenix.stable.toolchain;
  inherit (flake.lib.craneBuilder { inherit pkgs rustToolchain; }) craneLib;
in
craneLib.devShell {
  # Inherit inputs from checks.
  # Blueprint does not like this because it creates a check for this shell that in turn
  # is caught by this reference here and exposed as a check and so on...
  # tl,dr; Infinite recursion.
  # checks = flake.checks.${system};

  # Additional dev-shell environment variables can be set directly
  # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

  # Extra inputs can be added here; cargo and rustc are provided by default.
  packages = [
    # pkgs.ripgrep
  ];
}
