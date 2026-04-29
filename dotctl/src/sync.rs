use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, anyhow, bail};
use chrono::Local;

use crate::config::{DotctlConfig, TargetConfig};
use crate::document::{AnyDocument, Document};
use crate::path::FieldPath;

#[derive(Debug, Clone, Copy)]
pub enum Direction {
    Pull,
    Push,
    Sync,
}

#[derive(Debug, Clone, Copy)]
pub struct SyncOptions {
    pub dry_run: bool,
}

#[derive(Debug)]
struct Change {
    path: String,
    destination: Destination,
}

#[derive(Debug)]
enum Destination {
    Source,
    Target,
}

pub fn run(
    config: &DotctlConfig,
    name: Option<&str>,
    direction: Direction,
    options: SyncOptions,
) -> Result<()> {
    let targets = select_targets(config, name)?;
    for target in targets {
        run_target(target, direction, options)
            .with_context(|| format!("failed to process target {}", target.name))?;
    }
    Ok(())
}

fn select_targets<'a>(
    config: &'a DotctlConfig,
    name: Option<&str>,
) -> Result<Vec<&'a TargetConfig>> {
    if let Some(name) = name {
        let target = config
            .targets
            .get(name)
            .ok_or_else(|| anyhow!("unknown target: {name}"))?;
        Ok(vec![target])
    } else {
        Ok(config.targets.values().collect())
    }
}

fn run_target(target: &TargetConfig, direction: Direction, options: SyncOptions) -> Result<()> {
    let mut source = AnyDocument::load(
        &target.format,
        &target.source,
        matches!(direction, Direction::Pull | Direction::Sync),
    )?;
    let mut target_doc = AnyDocument::load(
        &target.format,
        &target.target,
        matches!(direction, Direction::Push),
    )?;

    let sync_paths = parse_paths(&target.sync)?;
    let deny_paths = parse_paths(&target.deny)?;
    validate_denied_paths(&source, &deny_paths)?;

    let changes = match direction {
        Direction::Pull => pull(&mut source, &target_doc, &sync_paths)?,
        Direction::Push => push(&source, &mut target_doc, &sync_paths)?,
        Direction::Sync => sync(&mut source, &mut target_doc, &sync_paths)?,
    };

    report_changes(target, direction, options, &changes);
    if options.dry_run || changes.is_empty() {
        return Ok(());
    }

    let writes_source = changes
        .iter()
        .any(|change| matches!(change.destination, Destination::Source));
    let writes_target = changes
        .iter()
        .any(|change| matches!(change.destination, Destination::Target));

    if writes_source {
        write_document(&target.source, source.to_string())?;
    }
    if writes_target {
        write_document(&target.target, target_doc.to_string())?;
    }

    Ok(())
}

fn pull(
    source: &mut dyn Document,
    target: &dyn Document,
    paths: &[ParsedPath],
) -> Result<Vec<Change>> {
    let mut changes = Vec::new();
    for path in paths {
        let Some(target_item) = target.get(&path.path) else {
            continue;
        };
        if source
            .get(&path.path)
            .is_some_and(|source_item| same_item(&source_item, &target_item))
        {
            continue;
        }
        source.set(&path.path, target_item)?;
        changes.push(Change {
            path: path.raw.clone(),
            destination: Destination::Source,
        });
    }
    Ok(changes)
}

fn push(
    source: &dyn Document,
    target: &mut dyn Document,
    paths: &[ParsedPath],
) -> Result<Vec<Change>> {
    let mut changes = Vec::new();
    for path in paths {
        let Some(source_item) = source.get(&path.path) else {
            continue;
        };
        if target
            .get(&path.path)
            .is_some_and(|target_item| same_item(&target_item, &source_item))
        {
            continue;
        }
        target.set(&path.path, source_item)?;
        changes.push(Change {
            path: path.raw.clone(),
            destination: Destination::Target,
        });
    }
    Ok(changes)
}

fn sync(
    source: &mut dyn Document,
    target: &mut dyn Document,
    paths: &[ParsedPath],
) -> Result<Vec<Change>> {
    let mut changes = Vec::new();
    for path in paths {
        let target_item = target.get(&path.path);
        let source_item = source.get(&path.path);

        match (target_item, source_item) {
            (Some(target_item), Some(source_item)) => {
                if !same_item(&target_item, &source_item) {
                    source.set(&path.path, target_item)?;
                    changes.push(Change {
                        path: path.raw.clone(),
                        destination: Destination::Source,
                    });
                }
            }
            (Some(target_item), None) => {
                source.set(&path.path, target_item)?;
                changes.push(Change {
                    path: path.raw.clone(),
                    destination: Destination::Source,
                });
            }
            (None, Some(source_item)) => {
                target.set(&path.path, source_item)?;
                changes.push(Change {
                    path: path.raw.clone(),
                    destination: Destination::Target,
                });
            }
            (None, None) => {}
        }
    }
    Ok(changes)
}

#[derive(Debug)]
struct ParsedPath {
    raw: String,
    path: FieldPath,
}

fn parse_paths(raw_paths: &[String]) -> Result<Vec<ParsedPath>> {
    raw_paths
        .iter()
        .map(|raw| {
            Ok(ParsedPath {
                raw: raw.clone(),
                path: FieldPath::parse(raw)?,
            })
        })
        .collect()
}

fn validate_denied_paths(source: &dyn Document, deny_paths: &[ParsedPath]) -> Result<()> {
    for path in deny_paths {
        if source.contains(&path.path) {
            bail!("source contains denied path: {}", path.raw);
        }
    }
    Ok(())
}

fn same_item(left: &toml_edit::Item, right: &toml_edit::Item) -> bool {
    left.to_string() == right.to_string()
}

fn report_changes(
    target: &TargetConfig,
    direction: Direction,
    options: SyncOptions,
    changes: &[Change],
) {
    let mode = if options.dry_run { "dry-run" } else { "apply" };
    println!("{} {:?} {}", target.name, direction, mode);

    if changes.is_empty() {
        println!("  No changes.");
        return;
    }

    for change in changes {
        let destination = match change.destination {
            Destination::Source => "source",
            Destination::Target => "target",
        };
        let prefix = if options.dry_run {
            "Would update"
        } else {
            "Update"
        };
        println!("  {prefix} {destination}: {}", change.path);
    }
}

fn write_document(path: &Path, content: String) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    if path.exists() {
        backup_file(path)?;
    }

    fs::write(path, content).with_context(|| format!("failed to write {}", path.display()))?;
    Ok(())
}

fn backup_file(path: &Path) -> Result<PathBuf> {
    let timestamp = Local::now().format("%Y%m%d-%H%M%S");
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| anyhow!("invalid backup file path: {}", path.display()))?;
    let mut backup = path.with_file_name(format!("{file_name}.bak.{timestamp}"));
    let mut index = 0;
    while backup.exists() {
        index += 1;
        backup = path.with_file_name(format!("{file_name}.bak.{timestamp}.{index}"));
    }
    fs::copy(path, &backup).with_context(|| {
        format!(
            "failed to back up {} to {}",
            path.display(),
            backup.display()
        )
    })?;
    Ok(backup)
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use super::*;
    use crate::config::TargetConfig;
    use crate::document::TomlDocument;

    fn toml_from(content: &str) -> TomlDocument {
        let dir = tempdir().unwrap();
        let path = dir.path().join("doc.toml");
        fs::write(&path, content).unwrap();
        TomlDocument::load(&path, false).unwrap()
    }

    fn parsed(paths: &[&str]) -> Vec<ParsedPath> {
        paths
            .iter()
            .map(|path| ParsedPath {
                raw: (*path).to_string(),
                path: FieldPath::parse(path).unwrap(),
            })
            .collect()
    }

    #[test]
    fn pull_extracts_only_sync_fields() {
        let mut source = toml_from("");
        let target = toml_from(
            r#"
project_doc_max_bytes = 65536

[projects."/secret"]
trust_level = "trusted"
"#,
        );
        let changes = pull(&mut source, &target, &parsed(&["project_doc_max_bytes"])).unwrap();
        assert_eq!(changes.len(), 1);
        assert!(
            source
                .get(&FieldPath::parse("project_doc_max_bytes").unwrap())
                .is_some()
        );
        assert!(source.get(&FieldPath::parse("projects").unwrap()).is_none());
    }

    #[test]
    fn push_preserves_unmanaged_target_fields() {
        let source = toml_from("project_doc_max_bytes = 65536\n");
        let mut target = toml_from(
            r#"
[projects."/secret"]
trust_level = "trusted"
"#,
        );
        push(&source, &mut target, &parsed(&["project_doc_max_bytes"])).unwrap();
        assert!(
            target
                .get(&FieldPath::parse("project_doc_max_bytes").unwrap())
                .is_some()
        );
        assert!(target.get(&FieldPath::parse("projects").unwrap()).is_some());
    }

    #[test]
    fn sync_uses_target_values_and_fills_missing_target_fields() {
        let mut source = toml_from(
            r#"
project_doc_max_bytes = 1
project_doc_fallback_filenames = ["CLAUDE.md"]
"#,
        );
        let mut target = toml_from("project_doc_max_bytes = 65536\n");
        sync(
            &mut source,
            &mut target,
            &parsed(&["project_doc_max_bytes", "project_doc_fallback_filenames"]),
        )
        .unwrap();

        let source_size = source
            .get(&FieldPath::parse("project_doc_max_bytes").unwrap())
            .unwrap();
        assert_eq!(source_size.as_value().unwrap().as_integer(), Some(65536));
        assert!(
            target
                .get(&FieldPath::parse("project_doc_fallback_filenames").unwrap())
                .is_some()
        );
    }

    #[test]
    fn deny_paths_fail_validation() {
        let source = toml_from(
            r#"
[tui.model_availability_nux]
"gpt-5.5" = 3
"#,
        );
        let err =
            validate_denied_paths(&source, &parsed(&["tui.model_availability_nux"])).unwrap_err();
        assert!(err.to_string().contains("denied path"));
    }

    #[test]
    fn push_requires_existing_source() {
        let dir = tempdir().unwrap();
        let target = TargetConfig {
            name: "codex".to_string(),
            format: "toml".to_string(),
            source: dir.path().join("missing.toml"),
            target: dir.path().join("target.toml"),
            sync: vec!["project_doc_max_bytes".to_string()],
            deny: Vec::new(),
        };

        let err = run_target(&target, Direction::Push, SyncOptions { dry_run: true }).unwrap_err();
        assert!(err.to_string().contains("file does not exist"));
    }
}
