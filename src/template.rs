//! Module for the template engine.
//!
//! This module contains the template engine that renders the markdown file with the dependencies data.
use std::{
    io,
    path::{Path, PathBuf},
};

use tera::{Context, Tera};
use thiserror::Error;

use crate::cargo_deny_list::CargoDenyList;

/// Renderer for the template engine.
pub struct TemplateRenderer {
    /// The actual template engine.
    engine: Tera,
    /// The path to the template file. Required by the engine.
    ///
    /// We will only be working with a single template in this program for now, so if
    /// by any chance we are not able to retrieve the name of the template file as the name,
    /// we will just put `String::default()` here so in the `render` step it can be referenced
    /// with the same name the template was saved with, even if it's an empty string.
    template_name: String,
}

/// Error type for the template engine.
#[derive(Debug, Error)]
pub enum TemplateError {
    /// Errors coming from the actual implementation of the templating engine.
    #[error("engine: {0}")]
    EngineImpl(tera::Error),
    /// Errors related to the template file handling.
    #[error("file validation: {0}")]
    FileValidation(io::Error),
    /// Errors related to the deserialization of the dependencies data.
    #[error("deserialization: {0}")]
    Deserialization(serde_json::Error),
}

impl TryFrom<PathBuf> for TemplateRenderer {
    type Error = TemplateError;
    fn try_from(path: PathBuf) -> Result<Self, Self::Error> {
        let path = path.canonicalize().map_err(TemplateError::FileValidation)?;

        validate_template_path(&path)?;

        let template_name = path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();

        let mut tera = Tera::default();
        tera.add_template_file(&path, Some(&template_name))
            .map_err(TemplateError::EngineImpl)?;

        Ok(Self {
            engine: tera,
            template_name,
        })
    }
}

/// Validates if the given path is a valid file.
fn validate_template_path<P: AsRef<Path>>(path: P) -> Result<(), TemplateError> {
    let path = path.as_ref();
    if !path.exists() {
        Err(TemplateError::FileValidation(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("Template file not found: {}", path.display()),
        )))
    } else if !path.is_file() {
        Err(TemplateError::FileValidation(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("Template path is not a file: {}", path.display()),
        )))
    } else {
        Ok(())
    }
}

impl TemplateRenderer {
    /// Renders the template with the given dependencies data.
    pub fn render(&self, dependencies_data: &str) -> Result<String, TemplateError> {
        let serialized = serde_json::from_str::<CargoDenyList>(dependencies_data)
            .map_err(TemplateError::Deserialization)?;

        let context = Context::from_serialize(serialized).map_err(TemplateError::EngineImpl)?;

        self.engine
            .render(&self.template_name, &context)
            .map_err(TemplateError::EngineImpl)
    }
}
