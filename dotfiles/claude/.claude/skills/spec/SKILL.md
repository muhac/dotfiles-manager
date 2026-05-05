---
description: Captures a discussed feature plan into structured design docs that /impl can consume. Use after discussion or /explore when ready to write specs.
when_to_use: When user says "write spec", "capture the plan", "document the design".
allowed-tools: Bash(git *)
argument-hint: "[ticket] [revise] [component]"
---

# Write Feature Spec

Captures a discussed feature plan into structured design docs that `/impl` can consume. Assumes discussion has already happened (optionally after `/explore`) — does NOT do codebase research.

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

### 2. Extract from conversation context

Scan the current conversation for the feature's decided plan. Extract:

- **Problem**: what problem does this solve
- **Architecture**: data flow, component interactions
- **Scope**: which repos/services/modules need changes and why
- **Components**: how the work breaks down into implementable units
- **Interface contracts**: interfaces across boundaries — function signatures, API endpoints, proto messages, CLI flags, shared types (applies to cross-repo, cross-service, and cross-module boundaries)
- **Design decisions**: key trade-offs and why this approach was chosen

If critical information is missing (e.g., no clear component breakdown, unclear scope), ask the user to fill in the gaps before proceeding. Do NOT invent answers — the conversation should already contain the plan.

### 3. Write design docs

Read CLAUDE.md for directory naming and grouping conventions (some projects organize by group, others are flat).

Create the feature directory and write:

**README.md** — shared context loaded by every `/impl` session.

For a **workspace** (multi-repo with submodules):

```markdown
# Feature Name

## Problem
[What problem does this solve, why is it needed]

## Architecture
[Data flow across repos. Use text diagrams if helpful.]

## Scope
[Which repos are involved and why. Which repos are NOT involved and why.]

## Interface Changes
[New or modified interfaces: CLI commands, API endpoints, SDK types,
proto definitions, config formats, UI pages/components, etc. Omit if none.]

## Interface Contracts
[Interfaces that must match across boundaries — repos, services, or modules.
Function signatures, message types, RPC names, CLI flags, shared types, etc.]

## Component Overview
| # | Component | Repo | Parallel | Dependencies | Description |
|---|-----------|------|----------|-------------|-------------|

## Related Features
[Links to related feature docs, if any. Omit if none.]

## Design Decisions
[Key trade-offs and why this approach was chosen]
```

For a **single repo**, simplify — drop Scope and the Repo column:

```markdown
# Feature Name

## Problem
[What problem does this solve, why is it needed]

## Architecture
[Data flow and component interactions. Use text diagrams if helpful.]

## Interface Changes
[New or modified interfaces. Omit if none.]

## Interface Contracts
[Interfaces that must match across services or modules.
Omit if the feature is self-contained within one module.]

## Component Overview
| # | Component | Parallel | Dependencies | Description |
|---|-----------|----------|-------------|-------------|

## Design Decisions
[Key trade-offs and why this approach was chosen]
```

**Component specs** — one numbered file per implementation session:

```markdown
# NN - Component Name

repo: <repo> or [repo1, repo2] if spanning multiple repos (omit for single repo)
branch: <branch-name>
status: pending | in_progress | completed | on_hold
parallel_with: [component numbers]
depends_on: [component numbers]

## Codebase analysis
[Existing code paths, key structures, and calling patterns relevant to this
component. Helps the implementer understand what exists before changing it.
Omit if the change is greenfield with no existing code to understand.]

## What to implement
[Files to create/modify with full paths]

## How to implement
[Key logic, pseudocode, patterns to follow — reference specific files
found during research]

## Interface contracts
[What this component produces or consumes from other components.
Function signatures, CLI flags, API endpoints, shared types that MUST match.
Omit if the component has no cross-boundary dependencies.]

## Runtime inputs
[Values only known after a prior component completes. Omit section if none.]
- name: <variable_name>
  from: component <NN>
  description: <what it is>

## Verification
- [ ] Linter passes
- [ ] Tests pass
- [ ] [Feature-specific checks]
```

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

- This skill turns discussion into docs — it does NOT research or propose solutions. Use `/explore` first if codebase research is needed.
- Keep README concise — prefer tables and diagrams over prose
- Component specs should be self-contained — one spec = one coding session
- Reference code by file path, not by pasting large blocks
- The `interface contracts` section is the most critical — it keeps parallel implementations consistent
- If the conversation context was compacted and key details were lost, ask the user rather than guessing
