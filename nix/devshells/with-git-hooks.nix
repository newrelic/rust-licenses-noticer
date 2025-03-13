{
  flake,
  system,
  pkgs,
  ...
}:
let
  gitHooks = flake.checks.${system}.git-hooks-crane-rust-toolchain;
in
pkgs.mkShell {
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
}
