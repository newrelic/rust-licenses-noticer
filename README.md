<a href="https://opensource.newrelic.com/oss-category/#community-project"><picture><source media="(prefers-color-scheme: dark)" srcset="https://github.com/newrelic/opensource-website/raw/main/src/images/categories/dark/Community_Project.png"><source media="(prefers-color-scheme: light)" srcset="https://github.com/newrelic/opensource-website/raw/main/src/images/categories/Community_Project.png"><img alt="New Relic Open Source community project banner." src="https://github.com/newrelic/opensource-website/raw/main/src/images/categories/Community_Project.png"></picture></a>

# Rust Licenses Noticer

[![Tests](https://github.com/newrelic/rust-licenses-noticer/actions/workflows/tests.yml/badge.svg)](https://github.com/newrelic/rust-licenses-noticer/actions/workflows/tests.yml)

Ensures the dependencies you declare in your `THIRD_PARTY_NOTICES.md` are in sync with the actual dependencies of your Rust project.

## Installation

At the moment the project is not on [`crates.io`](https://crates.io). To install, having the [Rust toolchain](https://rustup.rs) installed, you can run:

```sh
cargo install --git https://github.com/nerelic/rust-licenses-noticer.git
```

## Getting Started

This project is mostly intended to be used in your CI/CD pipelines, to ensure that your *attribution notices file* is in sync with the actual dependencies of your project, so it requires a certain setup. You can use this project as a GitHub Action or as a stand-alone program. Read below for details.

## Usage

### As a GitHub Action

The usage as a GitHub action assumes that you have a certain file in the root of your Rust project directory called `THIRD_PARTY_NOTICES.md`. This file lists the name of your dependencies, the URL in which they are located, and the licenses they distribute under. See this project's own [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md) as an example.

The action will take a template directory of your choice as its `template-path` input. Provided these templates are compatible with [Tera](https://keats.github.io/tera/docs/), a file will be rendered as `THIRD_PARTY_NOTICES.md` by using the template with the metadata retrieved about your Rust project with `cargo deny`. See the example template located at [`src/templates`](./src/templates/), which was used to generate our [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md), for an idea of possible templates.

Then, just use it inside your workflows.

```yaml
permissions:
  contents: read

on:
  push:
# See https://docs.github.com/en/actions/using-jobs/using-concurrency

concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true

name: ⚖ Third party licenses
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: newrelic/rust-licenses-noticer@main
        with:
          template-path: third_party_licenses_templates
          project-root: my-rust-project-directory # Optional
```

If the file rendered by the action does not match with the contents of the previous file, the action will fail letting you know that you have to sync the file with your dependencies, which you can achieve by running `rust-licenses-noticer`, as a program, locally in your project.

### Stand-alone program

#### Pre-requisites

You'll need to have installed [`cargo-deny`](https://github.com/EmbarkStudios/cargo-deny). Once you have it, retrieve the metadata from the root your Rust project's dependencies with something like this:

```sh
cargo deny --all-features --log-level off --manifest-path ./Cargo.toml list -l crate -f json
```

This will output a JSON that you can use as the `--dependencies` command line arguments, as shown below.

```sh
$ rust-licenses-noticer --help
Usage: rust-licenses-noticer [OPTIONS] --dependencies <DEPENDENCIES>

Options:
  -d, --dependencies <DEPENDENCIES>    Name of the person to greet
  -t, --template-path <TEMPLATE_PATH>  [default: src/templates/*]
  -o, --output-file <OUTPUT_FILE>      [default: THIRD_PARTY_NOTICES.md]
  -h, --help                           Print help
  -V, --version                        Print version
```

Provide templates compatible with [Tera](https://keats.github.io/tera/docs/) as a glob for `--template-path` to build the file output by `--output-file`.

For an example of actual usage as a program, check the golden tests at [`tests/golden`](./tests/golden) which contain a test that creates the command with the command line arguments and runs it.

## Building

If you have the [Rust toolchain](https://rustup.rs) installed, just `cargo build` will suffice.

## Testing

If you have the [Rust toolchain](https://rustup.rs) installed, just `cargo test` will run all.

## Support

If you find any problems while using the library or have a doubt, please feel free to open an [Issue](https://github.com/newrelic/rust-licenses-noticer/issues), where the New Relic maintainers of this project will be able to help.

## Contribute

We encourage your contributions to improve [project name]! Keep in mind that when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.

If you have any questions, or to execute our corporate CLA (which is required if your contribution is on behalf of a company), drop us an email at <opensource@newrelic.com>.

### A note about vulnerabilities

As noted in our [security policy](../../security/policy), New Relic is committed to the privacy and security of our customers and their data. We believe that providing coordinated disclosure by security researchers and engaging with the security community are important means to achieve our security goals.

If you believe you have found a security vulnerability in this project or any of New Relic's products or websites, we welcome and greatly appreciate you reporting it to New Relic through [our bug bounty program](https://docs.newrelic.com/docs/security/security-privacy/information-security/report-security-vulnerabilities/).

If you would like to contribute to this project, review [these guidelines](./CONTRIBUTING.md).

To all contributors, we thank you! Without your contribution, this project would not be what it is today.

## License

Rust Licenses Noticer is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.

This project also uses source code from third-party libraries. You can find full details on which libraries are used and the terms under which they are licensed in the [third-party notices document](./THIRD_PARTY_NOTICES.md).
