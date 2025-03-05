//! # Third Party Notices Generator
//!
//! `third-party-notices-generator` is a tool to generate a markdown file with the third party notices
//! of the dependencies of a project.
//!
//! The tool takes a JSON string with the dependency metadata as output by `cargo deny --manifest-path <PATH_TO_CARGO_TOML> list -l crate -f json` and generates a markdown file with the relevant information.

use clap::Parser;
use rust_licenses_noticer::template::{TemplateError, TemplateRenderer};
use std::path::PathBuf;
use std::{fs, io};
use thiserror::Error;

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {e}");
        std::process::exit(1);
    }
}

/// Arguments for the CLI
///
/// These are parsed automatically via the `clap` crate.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// JSON string with the dependencies data as output by `cargo deny list -l crate -f json`.
    #[arg(short, long)]
    dependencies: String,
    /// Path to the template file.
    #[arg(short, long)]
    template_file: PathBuf,
    /// Path to the output file.
    #[arg(short, long)]
    #[clap(default_value = "THIRD_PARTY_NOTICES.md")]
    output_file: PathBuf,
}

/// Error type for the main function.
///
/// This is a simple error type that wraps the errors that can happen in the `run` function.
#[derive(Debug, Error)]
enum RunError {
    /// Error related to file IO.
    #[error("file io: {0}")]
    Io(#[from] io::Error),
    /// Error related to the template engine.
    #[error("template: {0}")]
    Template(#[from] TemplateError),
}

/// Main function of the CLI.
///
/// This function is responsible for parsing the arguments, reading the template file,
/// rendering the template with the dependencies data and writing the output file.
///
/// # Errors
///
/// This function returns a `RunError` if any of the steps fails.
fn run() -> Result<(), RunError> {
    let args = Args::parse();

    let renderer = TemplateRenderer::try_from(args.template_file)?;

    let rendered = renderer.render(&args.dependencies)?;

    fs::write(&args.output_file, rendered)?;

    println!(
        "Third party notices file generated at: {}",
        args.output_file.display()
    );
    Ok(())
}
