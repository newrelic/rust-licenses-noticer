//! # Third Party Notices Generator
//!
//! `third-party-notices-generator` is a tool to generate a markdown file with the third party notices
//! of the dependencies of a project.
//!
//! The tool takes a JSON string with the dependency metadata as output by `cargo deny --manifest-path <PATH_TO_CARGO_TOML> list -l crate -f json` and generates a markdown file with the relevant information.

use serde_json::{Map, Value};
use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
use tera::{Context, Tera};

use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Name of the person to greet
    #[arg(short, long)]
    dependencies: String,
    #[arg(short, long)]
    template_path: PathBuf,
    #[arg(short, long)]
    #[clap(default_value = "THIRD_PARTY_NOTICES.md")]
    output_file: PathBuf,
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();

    let templates = Tera::new(&args.template_path.to_string_lossy())?;

    let mut f = File::create(args.output_file)?;
    let markdown = render_markdown(args.dependencies, &templates);
    match markdown {
        Ok(s) => Ok(f.write_all(s.as_bytes())?),
        Err(e) => {
            println!("Error: {}", e);
            let mut cause = e.source();
            while let Some(e) = cause {
                println!("Reason: {}", e);
                cause = e.source();
            }
            Err("Error rendering the template".into())
        }
    }
}

fn render_markdown(data: String, templates: &Tera) -> Result<String, Box<dyn Error>> {
    let serialized = serde_json::from_str::<Map<String, Value>>(data.as_str()).unwrap();

    let mut seen = HashSet::new();
    let mut unique_map = HashMap::new();

    for (key, value) in &serialized {
        if !key.is_empty() {
            let key_split: Vec<&str> = key.split_whitespace().collect();
            if seen.insert(key_split[0]) {
                unique_map.insert(key, value);
            }
        }
    }

    let mut context = Context::new();
    context.insert("dependencies", &unique_map);

    // A one off template
    Tera::one_off("hello", &Context::new(), true).unwrap();

    Ok(templates.render("THIRD_PARTY_NOTICES.md.tmpl", &context)?)
}
