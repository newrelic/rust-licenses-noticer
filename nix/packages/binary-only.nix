{
  pkgs,
  ...
}:
let
  # This is a binding to a definition of the package that can be added as-is to nixpkgs!
  rust-licenses-noticer =
    {
      lib,
      rustPlatform,
      fetchFromGitHub,
    }:
    rustPlatform.buildRustPackage rec {
      pname = "rust-licenses-noticer";
      version = "1.0.0";

      src = fetchFromGitHub {
        owner = "newrelic";
        repo = "rust-licenses-noticer";
        rev = "v${version}";
        hash = "sha256-RR0LBRYuZQv/6KpBD2Tw88CHmnXZIUX1yWLVqOl7+S0=";
      };

      cargoLock.lockFile = "${src}/Cargo.lock";

      meta = {
        description = "";
        homepage = "https://github.com/newrelic/rust-licenses-noticer";
        license = lib.licenses.asl20;
        maintainers = with lib.maintainers; [ davsanchez ];
        mainProgram = "rust-licenses-noticer";
      };
    };
in
# Here, we just call the package defined above
pkgs.callPackage rust-licenses-noticer {
  inherit (pkgs)
    lib
    rustPlatform
    fetchFromGitHub
    ;
}
