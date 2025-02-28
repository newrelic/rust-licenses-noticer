//! This test is a golden test that compares a known output of a `cargo-deny` command with a
//! known good output. The test is run in a temporary directory to avoid any issues with
//! the current directory of the test runner.
//!
//! The test is run by invoking our actual binary with the known output file as input and a known
//! good template file. The output is then compared to the known good output file.
//!
//! This helps to make sure no modification of this crate break how this template is generated, so
//! this test is generally **not intended to be modified**.
//! Any change on `rust-licenses-noticer` that breaks how the notices file is generated
//! will be caught here.
use std::{
    fs,
    path::{Path, PathBuf},
};

use assert_cmd::Command;
use assert_fs::{assert::PathAssert, prelude::PathChild};

fn fixtures_path() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("golden")
        .join("fixtures")
}

#[test]
fn golden() {
    let tmp_dir = assert_fs::TempDir::new().unwrap();

    let cargo_deny_output =
        fs::read_to_string(fixtures_path().join("cargo_deny_output.json")).unwrap();

    let mut cmd = Command::cargo_bin(env!("CARGO_PKG_NAME")).unwrap();
    cmd.current_dir(tmp_dir.path())
        .arg("--dependencies")
        .arg(cargo_deny_output)
        .arg("--templates-path")
        .arg(fixtures_path().join("templates").join("*"))
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
        fixtures_path().join("expected_third_party_notices_file.md"),
    ));
}
