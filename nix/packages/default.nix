{
  pkgs,
  perSystem,
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
    ++ [ perSystem.self.binary-only ];

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
}
