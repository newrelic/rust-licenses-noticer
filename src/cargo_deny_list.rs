//! Module for parsing the output of the calls to `cargo deny`.
//!
//! The assumption is that the input to the [CargoDenyList] type is the result of running the
//! command `cargo deny list -l crate -f json`.
//!
//! The result of such a command is a JSON object with the following structure:
//!
//! ```json
//! {
//!    "adler2 2.0.0 registry+https://github.com/rust-lang/crates.io-index": {
//!       "licenses": [
//!         "0BSD",
//!        "MIT",   
//!       "Apache-2.0"
//!      ]
//!   },
//!
//! // More dependencies...
//! }
//! ```
//!
//! This module parses this JSON object into a more usable format for our use case.
//! See [CargoDenyList] type for more information.
use std::collections::HashMap;

use serde::{Deserialize, Deserializer, Serialize};

/// Represents the output of a call to `cargo deny list -l crate -f json`, adapted to our use case.
///
/// The output of that command is a JSON object. The keys are strings with the following pattern:
///
/// ```text
/// <CRATE_NAME> <CRATE_VERSION> <REGISTRY_TYPE>+<URL>
/// ```
///
/// While the values are JSON objects with the following structure:
/// ```json
/// {
///   "licenses": [
///     "MIT",
///     "Apache-2.0"
///   ]
/// }
///
/// We are only interested in the dependency name, its URL, and the licenses it uses.
/// So that's what we store.
#[derive(Debug, Serialize, PartialEq)]
pub(super) struct CargoDenyList {
    /// Map of dependencies and their licenses.
    dependencies: HashMap<NameAndUrl, LicenseList>,
}

impl<'de> Deserialize<'de> for CargoDenyList {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        Ok(CargoDenyList {
            dependencies: HashMap::deserialize(deserializer)?,
        })
    }
}

/// Represents the licenses used by a dependency.
///
/// The `licenses` field is a list of strings with the short names
/// of the licenses used by the dependency.
#[derive(Debug, Deserialize, Serialize, PartialEq)]
#[cfg_attr(test, derive(Default))]
struct LicenseList {
    /// List of licenses used by the dependency.
    licenses: Vec<String>,
}

/// Represents the name of a dependency and its URL.
///
/// The format of this string is expected to be:
///
/// ```text
/// <CRATE_NAME> <URL>
/// ```
///
/// The URL is formatted as a link to the dependency's page.
#[derive(Debug, PartialEq, Eq, Hash, Serialize)]
struct NameAndUrl(String);

impl<'de> Deserialize<'de> for NameAndUrl {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let key = String::deserialize(deserializer)?;
        let key_split = key.split_whitespace().collect::<Vec<_>>();

        match key_split[..] {
            [crate_name, _crate_version, url] => Ok(NameAndUrl(format!(
                "{} {}",
                crate_name,
                process_name_with_url(crate_name, url)
            ))),
            _ => Err(serde::de::Error::custom("Invalid dependency key format")),
        }
    }
}

/// Given a dependency name and a URL, returns a string with the URL formatted as a link to the
/// dependency's page.
///
/// # Examples
///
/// ```ignore
/// let dep_name = "adler2";
/// let url_str = "registry+https://github.com/rust-lang/crates.io-index";
/// let result = process_name_with_url(dep_name, url_str);
/// assert_eq!(result, "https://crates.io/crates/adler2");
/// ```
///
/// If the URL is from git, the `.git` suffix is removed:
///
/// ```ignore
/// let dep_name = "rust-licenses-noticer";
/// let url_str = "git+https://github.com/newrelic/rust-licenses-noticer.git";
/// let result = process_name_with_url(dep_name, url_str);
/// assert_eq!(result, "https://github.com/newrelic/rust-licenses-noticer");
/// ```
fn process_name_with_url(dep_name: &str, url_str: &str) -> String {
    match url_str {
        // crates.io
        "registry+https://github.com/rust-lang/crates.io-index" => {
            format!("https://crates.io/crates/{}", dep_name)
        }
        // remove any prefix for other registries, up until the + symbol
        s if s.starts_with("git+") => remove_source_prefix(s).trim_end_matches(".git").to_string(),
        s => remove_source_prefix(s),
    }
}

/// Removes the prefix of a URL string up until the + symbol.
/// If the URL doesn't have a + symbol, the string is returned as is.
///
/// # Examples
///
/// ```ignore
/// let url_str = "git+https://github.com/newrelic/rust-licenses-noticer.git";
/// let result = remove_source_prefix(url_str);
/// assert_eq!(result, "https://github.com/newrelic/rust-licenses-noticer.git");
/// ```
fn remove_source_prefix(url_str: &str) -> String {
    // Is there a registry indicator? We know it's a registry if it has a + symbol at the end.
    let sum_symbol_index = url_str.find('+').map(|i| i + 1).unwrap_or(0);
    url_str.chars().skip(sum_symbol_index).collect::<String>()
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    #[test]
    fn basic_test() {
        let input = json!({
            "adler2 2.0.0 registry+https://github.com/rust-lang/crates.io-index": {
                "licenses": [
                    "0BSD",
                    "MIT",
                    "Apache-2.0"
                    ]
                },
        });

        let expected = CargoDenyList {
            dependencies: vec![(
                NameAndUrl("adler2 https://crates.io/crates/adler2".to_string()),
                LicenseList {
                    licenses: vec![
                        "0BSD".to_string(),
                        "MIT".to_string(),
                        "Apache-2.0".to_string(),
                    ],
                },
            )]
            .into_iter()
            .collect(),
        };

        let actual: CargoDenyList = serde_json::from_value(input).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn basic_test_git() {
        let input = json!({
            "rust-licenses-noticer 0.1.0 git+https://github.com/newrelic/rust-licenses-noticer.git": {
                "licenses": [ ]
                },
        });

        let expected = CargoDenyList {
            dependencies: vec![(
                NameAndUrl(
                    "rust-licenses-noticer https://github.com/newrelic/rust-licenses-noticer"
                        .to_string(),
                ),
                LicenseList::default(),
            )]
            .into_iter()
            .collect(),
        };

        let actual: CargoDenyList = serde_json::from_value(input).unwrap();

        assert_eq!(expected, actual);
    }

    #[test]
    fn basic_test_serde() {
        let input = json!({
            "adler2 2.0.0 registry+https://github.com/rust-lang/crates.io-index": {
                "licenses": [
                    "0BSD",
                    "MIT",
                    "Apache-2.0"
                    ]
                },
        });

        let expected_value = json!({
            "adler2 https://crates.io/crates/adler2": {
                "licenses": [
                    "0BSD",
                    "MIT",
                    "Apache-2.0"
                    ]
                },
        });

        let deserialized = serde_json::from_value::<CargoDenyList>(input)
            .unwrap()
            .dependencies;
        let serialized = serde_json::to_value(deserialized).unwrap();

        assert_eq!(expected_value, serialized);
    }
}
