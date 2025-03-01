//! # Third Party Notices Generator
//!
//! `third-party-notices-generator` is a tool to generate a markdown file with the third party notices
//! of the dependencies of a project.
//!
//! The tool takes a JSON string with the dependency metadata as output by `cargo deny --manifest-path <PATH_TO_CARGO_TOML> list -l crate -f json` and generates a markdown file with the relevant information.

use rust_licenses_noticer::template::TemplateRenderer;
use std::error::Error;
use std::fs;
use std::path::PathBuf;

use clap::Parser;

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
    template_path: PathBuf,
    /// Path to the output file. Will use `THIRD_PARTY_NOTICES.md` by default.
    #[arg(short, long)]
    #[clap(default_value = "THIRD_PARTY_NOTICES.md")]
    output_file: PathBuf,
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();

    let renderer = TemplateRenderer::try_from(args.template_path)?;

    let rendered = renderer.render(&args.dependencies)?;

    fs::write(&args.output_file, rendered)?;

    println!(
        "Third party notices file generated at: {}",
        args.output_file.display()
    );
    Ok(())
}
