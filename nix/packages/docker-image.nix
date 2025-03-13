{
  pkgs,
  flake,
  system,
  ...
}:
# Want even more possibilities for containers? Check out <https://github.com/nlewo/nix2container>
pkgs.dockerTools.buildImage {
  name = "rust-licenses-noticer-image";
  tag = "latest";

  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths =
      [
        flake.packages.${system}.with-crane-cross-x86_64-linux-musl
      ]
      ++ (
        # Not needed, just to show pinned versions of packages
        with pkgs; [
          cargo
          cargo-deny
          git
        ]);
    pathsToLink = [ "/bin" ];
  };

  # config = {
  #   Cmd = [
  #     "/bin/rust-licenses-noticer"
  #   ];
  # };
}
