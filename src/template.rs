//! Module for the template engine.
//!
//! This module contains the template engine that renders the markdown file with the dependencies data.
use std::path::PathBuf;

use tera::{Context, Tera};
use thiserror::Error;

use crate::cargo_deny_list::CargoDenyList;

/// Renderer for the template engine.
pub struct TemplateRenderer(Tera);

/// Error type for the template engine.
#[derive(Debug, Error)]
pub enum TemplateError {
    /// Errors coming from the actual implementation of the templating engine.
    #[error("Templating engine error: {0}")]
    EngineImpl(tera::Error),
}

impl TryFrom<PathBuf> for TemplateRenderer {
    type Error = TemplateError;
    fn try_from(path: PathBuf) -> Result<Self, Self::Error> {
        let tera = Tera::new(path.to_string_lossy().as_ref()).map_err(TemplateError::EngineImpl)?;
        Ok(Self(tera))
    }
}

impl TemplateRenderer {
    /// Renders the template with the given dependencies data.
    pub fn render(&self, dependencies_data: &str) -> Result<String, TemplateError> {
        let serialized = serde_json::from_str::<CargoDenyList>(dependencies_data).unwrap();

        let context = Context::from_serialize(serialized).map_err(TemplateError::EngineImpl)?;

        self.0
            .render("THIRD_PARTY_NOTICES.md.tmpl", &context)
            .map_err(TemplateError::EngineImpl)
    }
}
