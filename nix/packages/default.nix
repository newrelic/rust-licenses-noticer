{
  pkgs,
  flake,
  system,
  ...
}:
pkgs.writeShellApplication {
  name = "third-party-licenses-check";

  runtimeInputs =
    with pkgs;
    [
      cargo
      cargo-deny
      git
    ]
    ++ [
      flake.packages.${system}.binary-only
    ];

  text = ''
    LICENSES=$(cargo deny --all-features --manifest-path "$(pwd)/Cargo.toml" list -l crate -f json)
    echo "$LICENSES"

    rust-licenses-noticer --dependencies "$LICENSES" --output-file "THIRD_PARTY_NOTICES.md" --template-file "THIRD_PARTY_NOTICES.md.tmpl"

    STATUS=$(git status --porcelain --untracked-files=all -- "THIRD_PARTY_NOTICES.md")

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
}
