---
description: Researches the codebase and gathers context for a feature or topic. Use when exploring code, understanding architecture, or preparing for /spec.
when_to_use: When user asks how something works, where code lives, wants to understand a feature area, or says "explore", "investigate", "look into".
argument-hint: "[ticket-or-topic] [repo-alias]"
---

# Explore Codebase

Researches the codebase and gathers context for a feature or topic. Produces structured findings to fuel discussion — does NOT write design docs (use `/spec` after discussion).

## Usage

```text
/explore PROJ-123               # lookup ticket + explore all repos
/explore PROJ-123 cli           # explore only one repo (by alias, workspace only)
/explore some topic             # explore by topic (no ticket)
```

$ARGUMENTS

## Prerequisites

This skill reads the following from CLAUDE.md. If CLAUDE.md doesn't exist, suggest running `/setup` first. If specific sections are missing, warn and proceed with what's available.

- **Repo Map** — table of repos with paths and aliases (workspace only; single repo can skip)
- **Feature Design Docs** — where design docs live (for checking prior work)

## Steps

### 1. Determine scope

Parse `$ARGUMENTS`:
- If it contains a ticket ID (e.g., `PROJ-123`) → run ticket lookup
- If it contains a repo alias (workspace only) → limit research to that repo (match against Repo Map in CLAUDE.md)
- Otherwise treat the entire argument as a topic description

**Ticket lookup** (skip if no ticket ID):

Use any available MCP tools to look up the ticket (e.g., Linear, Jira, Glean). These are optional — if unavailable, skip and inform the user.

Present what was found and ask: "Anything to add before I explore the codebase?"

If the user provides additional context, incorporate it before proceeding.

### 2. Sync repos

**Workspace** (multi-repo with submodules): read the **Repo Map** from CLAUDE.md for the list of repos and their paths. Ensure submodules are initialized:
```bash
git -C <repo-path> rev-parse --git-dir    # one per repo, parallel
```
If any fails, run `git submodule update --init --recursive`.

Then sync each repo to its default branch (parallel):
```bash
git -C <repo-path> fetch origin && git -C <repo-path> checkout <default-branch> && git -C <repo-path> pull --rebase origin <default-branch>
```

If a repo has uncommitted changes, report it and skip that repo.

**Single repo**: just `git fetch origin` — don't switch branches or force a clean state.

Do NOT create a feature branch — this is exploration, not implementation.

### 3. Research

**Workspace**: spawn **Explore agents in parallel** — one per repo in scope. For each repo, read its own CLAUDE.md for conventions and key directories.

**Single repo**: spawn a single **Explore agent** for the current repo. Read the project's CLAUDE.md for context.

**Agent prompt** (adapt `[topic]` from step 1):

```text
Research how [topic] relates to existing code in <repo-path>.

Read the repo's CLAUDE.md and any convention docs for context first.

Return a **structured list** (not prose):
1. Relevant file paths and what they do
2. Key patterns and abstractions to follow or be aware of
3. Interfaces/contracts at boundaries (API endpoints, SDK types, CLI flags, etc.)
4. Existing tests related to this area
5. Whether this area likely needs changes for [topic] (yes/no/maybe with reasoning)
6. Risks or gotchas
```

### 4. Present findings

Synthesize the research into a structured summary. Adapt the table to the project type — skip rows that don't apply (e.g., single repo doesn't need "Scope"):

| Area | Finding |
|------|---------|
| **Scope** | Which repos/services/modules need changes and why (workspace: per-repo; single repo: per-module) |
| **Key files** | Most important files to understand (with paths) |
| **Existing patterns** | Patterns to follow or extend |
| **Interface boundaries** | Contracts across repos, services, or modules |
| **Gaps** | What doesn't exist yet and needs to be built |
| **Risks** | Surprising findings, conflicts, or complexity |

If the research raised questions that affect the approach, list them explicitly.

No checkpoint gate — this is informational. The user will discuss, ask follow-ups, or pivot. When the discussion converges, suggest `/spec` to capture it.

## Tips

- Keep findings factual — report what exists, don't propose solutions (that's discussion + `/spec`)
- Reference code by file path and line range, not by pasting large blocks
- If a repo is clearly not relevant, say so briefly rather than forcing a finding
- The user may run `/explore` multiple times with different filters as discussion narrows scope
