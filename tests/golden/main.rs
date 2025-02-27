use std::{fs, path::Path};

use assert_cmd::Command;
use assert_fs::{assert::PathAssert, prelude::PathChild};

#[test]
fn golden() {
    let tmp_dir = assert_fs::TempDir::new().unwrap();

    let cargo_deny_output = fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests")
            .join("golden")
            .join("fixtures")
            .join("cargo_deny_output.json"),
    )
    .unwrap();

    let mut cmd = Command::cargo_bin(env!("CARGO_PKG_NAME")).unwrap();
    cmd.current_dir(tmp_dir.path())
        .arg("--dependencies")
        .arg(cargo_deny_output)
        .arg("--template-path")
        .arg(
            Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("src")
                .join("templates")
                .join("*"),
        )
        .arg("--output-file")
        .arg(tmp_dir.path().join("THIRD_PARTY_NOTICES.md"));

    // Assertions
    cmd.assert().success();

    // The file is created and is equal to the golden test file
    let actual_file = tmp_dir.child("THIRD_PARTY_NOTICES.md");

    // TODO: If this assertion fails, the bit slice of the file will be printed to the output
    // which is not readable at all. We should either do a comparison ourselves to provide
    // pretty printing or ignore the output altogether, set a breakpoint at the assertion and
    // perform a manual diff after inspecting where the temp dir is created:
    // `diff tests/fixtures/expected_third_party_notices_file.md <TMP_DIR>/THIRD_PARTY_NOTICES.md`
    actual_file.assert(predicates::path::eq_file(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests")
            .join("golden")
            .join("fixtures")
            .join("expected_third_party_notices_file.md"),
    ));
}
