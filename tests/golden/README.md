# `rust-licenses-noticer` golden test

The contents of the `golden` test crate help to make sure no modification of this crate break how this template is generated.

There are two files in the `fixtures` directory:

- `cargo_deny_output.json` represents the output of running `cargo deny --all-features --manifest-path ./Cargo.toml list -l crate -f json` inside the root directory of the `newrelic-oauth-client-rs` repository, [at a certain revision](https://github.com/newrelic/newrelic-oauth-client-rs/blob/215ab8440e9418ea48b8c6726ac4a1a2e75eb1e1/Cargo.toml). The tooling versions used are:
  - `cargo` 1.85.0
  - `cargo-deny` 0.16.3
  - The logic for the generation belongs to [this revision](https://github.com/newrelic/newrelic-agent-control/blob/fc327420b5e1c63fbaa6525cf8bf95e3f1ce7e5b/license/src/main.rs#L1).
- `expected_third_party_notices_file.md` is a third party notices file, as generated from the previous JSON contents passed through `rust-licenses-noticer` in a known previous state. Specifically, before the crate was moved to this repository, with the template tailored to `newrelic-oauth-client-rs`.

Any change on `rust-licenses-noticer` that breaks how the notices file is generated will be caught here.
