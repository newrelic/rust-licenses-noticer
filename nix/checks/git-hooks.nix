{
  inputs,
  system,
  # perSystem, # Uncomment this to trigger the errors reported at <https://github.com/numtide/blueprint/issues/79>
  ...
}:
inputs.git-hooks.lib.${system}.run {
  src = ../../.; # The root directory of the flake
  hooks = {
    # Rust
    cargo-check.enable = true;
  };
}
