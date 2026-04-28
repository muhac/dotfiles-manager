---
description: Ensures CLAUDE.md has the sections that /explore, /spec, and /impl expect. Detects project structure and fills in what's missing.
disable-model-invocation: true
---

# Setup CLAUDE.md

Ensures CLAUDE.md has the sections that `/explore`, `/spec`, and `/impl` expect. Detects the project structure and fills in what's missing — does not overwrite existing content.

## Usage

```text
/setup                   # auto-detect and fill missing sections
/setup refresh           # re-scan project and update stale sections (e.g., repo map changed)
```

$ARGUMENTS

## Steps

### 1. Detect project structure

Scan the current workspace to determine:

**Repo type:**
- **Multi-repo (submodules)**: `.gitmodules` exists → read it for repo list and paths
- **Monorepo**: multiple top-level directories with distinct purposes but single git root
- **Single repo**: one project, one git root

**For multi-repo**, extract from `.gitmodules`:
- Repo names and paths (e.g., `repos/go-servers`)
- Remote URLs

**For all types**, detect:
- Primary language(s) and build system (look for `go.mod`, `package.json`, `pyproject.toml`, `Cargo.toml`, `Makefile`, etc.)
- Default branch: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo main`
- Existing CLAUDE.md content (if any)
- Existing convention docs (look for `docs/conventions/`, repo-level CLAUDE.md files)
- Existing design docs (look for `docs/features/`, `docs/design/`, `docs/rfcs/`)
- Existing CI/CD (`.github/workflows/`, `.gitlab-ci.yml`, etc.)

### 2. Identify gaps

Read the existing CLAUDE.md (if it exists). Check which of these sections are present:

| Section | Required by | Purpose |
|---------|------------|---------|
| **Repo Map** | `/explore`, `/spec`, `/impl` | Repos, paths, default branches, tech stack |
| **Repo-Specific Conventions** | `/impl` | Convention doc paths per repo |
| **Feature Design Docs** | `/spec`, `/impl` | Where design docs live, naming convention, feature index |
| **Git Rules** | `/spec`, `/impl` | Branch naming, commit format, submodule conventions |
| **Cross-Repo Change Rules** | `/spec` | Dependency ordering, component sequencing preferences |

For single-repo projects, **Repo Map**, **Repo-Specific Conventions**, and **Cross-Repo Change Rules** can be omitted or simplified.

### 3. Present plan

**CHECKPOINT — Do NOT write anything until the user approves.**

Show what was detected and what will be added or updated:

- Project type (single/mono/multi-repo)
- Sections that already exist (will be kept as-is, unless `refresh` mode)
- Sections that will be added (with draft content)
- Sections that are optional for this project type (and why)

In `refresh` mode, also show sections that appear outdated (e.g., repo map doesn't match current `.gitmodules`).

Ask: "approve" to write / edit the drafts / skip specific sections.

### 4. Write CLAUDE.md

If CLAUDE.md doesn't exist, create it. If it does, append missing sections — do NOT reorder or rewrite existing content.

Use the templates below, filled in with detected values.

---

### Templates

**Repo Map** (multi-repo):
```markdown
## Repo Map

| Repo | Path | Default Branch | Tech Stack | Purpose |
|------|------|---------------|-----------|---------|
| <name> | `repos/<name>/` | main | <detected> | <brief> |

Each repo has a `CLAUDE.md` at its root with build/test/lint commands. Read it when working in that repo.
```

**Repo Map** (single repo — simplified):
```markdown
## Tech Stack

<language>, <framework>, <build tool>
```

**Repo-Specific Conventions** (multi-repo, only if convention docs exist):
```markdown
## Repo-Specific Conventions

| Repo | Convention Doc |
|------|---------------|
| <name> | `docs/conventions/<name>.md` |

Also read the repo's own `repos/<repo>/CLAUDE.md` for repo-level guidelines.
```

**Feature Design Docs**:
```markdown
## Feature Design Docs

Design docs live in `docs/features/<feature-name>/`. Each has:
- `README.md` — shared context (problem, architecture, scope, contracts)
- Numbered component specs (`01-*.md`, `02-*.md`, ...) — per-component implementation details

Feature index: `docs/features/README.md`
```

**Git Rules** (multi-repo):
```markdown
## Git Rules

- Code changes go to **submodule repos** (not the parent repo)
- Design docs and status updates go to **this repo**
- Submodules use `ignore = all` — parent `git status` stays clean
- Branch naming: `<ticket>-<feature-name>` (no slashes)
- Commit format: `feat/fix/design/status(<ticket>): message`
```

**Git Rules** (single repo):
```markdown
## Git Rules

- Branch naming: `<ticket>-<feature-name>`
- Commit format: `feat/fix/design(<scope>): message`
```

**Cross-Repo Change Rules** (multi-repo only):
```markdown
## Cross-Repo Change Rules

[Detected dependency patterns, e.g.:]
1. Proto/schema changes → regenerate downstream code
2. Shared library changes → verify all consumers
3. API changes → update both server and client repos
```

### 5. Create supporting files (if missing)

If Feature Design Docs section was added and the directory doesn't exist yet:

```bash
mkdir -p docs/features
```

Create `docs/features/README.md` with an empty feature index:
```markdown
# Feature Index

| Feature | Ticket | Status | Description |
|---------|--------|--------|-------------|
```

If convention docs were referenced but `docs/conventions/` doesn't exist, create the directory but do NOT generate convention doc content — that should be written by someone who knows the repo.

### 6. Summary

Show what was written. Remind the user:
- Review and edit the generated sections — they're a starting point, not final
- Convention docs (if referenced) need to be written manually
- The feature index will be populated as `/spec` is used

Do NOT commit — let the user review first.

## Tips

- This skill is additive — it never removes or rewrites existing CLAUDE.md content (except in `refresh` mode for specific sections)
- For single-repo projects, keep it minimal — don't force multi-repo structure
- The detected tech stack and purpose descriptions are best-effort — user should verify
- If `.gitmodules` references repos that aren't cloned yet, note them as "not initialized"
