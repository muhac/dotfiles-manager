---
description: Captures a discussed feature plan into structured design docs that /impl can consume. Use after discussion or /task when ready to write specs.
when_to_use: When user says "write spec", "capture the plan", "document the design".
allowed-tools: Read Bash(git *) Bash(cd * && git *)
argument-hint: "[ticket] [revise] [component]"
---

# Write Feature Spec

Captures a discussed feature plan into structured design docs that `/impl` can consume. Assumes discussion has already happened (optionally after `/task`) — does NOT do codebase research.

## Usage

```text
/spec PROJ-123                   # write docs from conversation context
/spec PROJ-123 revise            # revise existing design docs
/spec PROJ-123 revise 02         # revise only component 02 spec
```

$ARGUMENTS

## Prerequisites

This skill reads the following from CLAUDE.md. If CLAUDE.md doesn't exist, suggest running `/setup` first.

- **Repo Map** — repos, paths, default branches (workspace only; single repo can skip)
- **Feature Design Docs** — where design docs live (e.g., `docs/features/`), directory naming convention, feature index file
- **Git Rules** — branch naming convention, commit format
- **Cross-Repo Change Rules** — component ordering preferences (workspace only)

## Steps

### 1. Parse request and setup

Parse `$ARGUMENTS` for feature name/ticket ID and mode (`revise` or new).

Read CLAUDE.md for the **Feature Design Docs** section to determine:
- Design doc directory (default: `docs/features/`)
- Feature index file (default: `docs/features/README.md`)
- Branch naming convention

If this is a **new** design (not revise), set up the branch. Read CLAUDE.md (or check `git symbolic-ref refs/remotes/origin/HEAD`) for the default branch name:
```bash
git fetch origin && git checkout <default-branch> && git pull --rebase origin <default-branch>
git checkout <branch-name> 2>/dev/null || git checkout -b <branch-name>
```

### 2. Extract from conversation context and task.md

Check if a `task.md` exists in the feature directory (produced by `/task`). If it does, read it — it contains research findings, diagrams, dependency chains, and interface boundaries that inform the spec.

Scan both `task.md` (if present) and the current conversation for the feature's decided plan. Extract:

- **Problem**: what problem does this solve
- **Architecture**: data flow, component interactions (leverage diagrams from `task.md` if available)
- **Scope**: which repos/services/modules need changes and why
- **Components**: how the work breaks down into implementable units
- **Interface contracts**: interfaces across boundaries — function signatures, API endpoints, proto messages, CLI flags, shared types (applies to cross-repo, cross-service, and cross-module boundaries)
- **Design decisions**: key trade-offs and why this approach was chosen

If critical information is missing (e.g., no clear component breakdown, unclear scope), ask the user to fill in the gaps before proceeding. Do NOT invent answers — the conversation and `task.md` should already contain the plan.

### 3. Write design docs

Read CLAUDE.md for directory naming and grouping conventions (some projects organize by group, others are flat).

Create the feature directory and write:

**README.md** — shared context loaded by every `/impl` session. Use the [readme template](../_shared/templates/spec-readme.md). Sections marked with `>>> WORKSPACE ONLY <<<` are included only for multi-repo workspaces; for single repos, drop those sections and the Repo column from Component Overview.

**Component specs** — one numbered file per implementation session. Use the [component template](../_shared/templates/spec-component.md).

**Component ordering** — read CLAUDE.md for project-specific ordering rules. General defaults:
1. Foundational changes (proto, shared types) come first
2. Independent backend/service components can be parallel
3. UI/integration components come last
4. Documentation depends on behavior being finalized

**Feature index** — update the feature index file (if it exists):
```markdown
| <feature-name> | <ticket> | In Design | Brief description |
```

**Commit initial draft**:
```bash
git add <design-doc-directory>
git commit -m "design(<ticket>): initial draft"
```

### 4. Present to user

**CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.**

Show the user the generated design docs. Focus on whether the specs are accurate, complete, and actionable.

Use `AskUserQuestion` to let the user choose:
- Option A: "Approve and push" — proceed to push
- Option B: "Revise" — describe changes to the specs
- Option C: "Discuss" — ask questions before deciding

If revisions are requested, apply them and commit each round:
```bash
git commit -m "design(<ticket>): <what changed>"
```

Repeat until approved.

### 5. Push

```bash
git push -u origin HEAD
```

## Revise Mode

When invoked with `revise` or `revise NN`:

1. **Read existing docs** — read the feature README and relevant component specs
2. **Gather changes** — ask the user what needs to change. If the conversation already contains the changes, extract from context instead of asking.
3. **Update docs** — modify README and/or component specs. When adding components, follow ordering rules. When removing components, update `depends_on` and `parallel_with` in affected specs.
4. **CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.** Present changes: "Approve and push" / "Revise" / "Discuss".
5. **Commit and push**:
```bash
git add <design-doc-directory>
git commit -m "design(<ticket>): revise <what changed>"
git push -u origin HEAD
```

## Tips

- This skill turns discussion into docs — it does NOT research or propose solutions. Use `/task` first if codebase research is needed.
- Keep README concise — prefer tables and diagrams over prose
- Component specs should be self-contained — one spec = one coding session
- Reference code by file path, not by pasting large blocks
- The `interface contracts` section is the most critical — it keeps parallel implementations consistent
- If the conversation context was compacted and key details were lost, ask the user rather than guessing
