---
description: Researches the codebase and gathers context for a feature or topic. Produces a task.md document with diagrams to fuel /spec.
when_to_use: When user has a new task or ticket, wants to understand a feature area, or says "task", "explore", "investigate", "look into".
allowed-tools: Bash(git *) Bash(cd * && git *)
argument-hint: "[ticket-or-topic] [repo-alias]"
---

# Research Task

Researches the codebase in depth and produces a structured `task.md` document with diagrams. The document serves as input for discussion and `/spec`.

## Usage

```text
/task PROJ-123               # lookup ticket + explore all repos
/task PROJ-123 cli           # explore only one repo (by alias, workspace only)
/task some topic             # explore by topic (no ticket)
```

$ARGUMENTS

## Prerequisites

This skill reads the following from CLAUDE.md. If CLAUDE.md doesn't exist, suggest running `/setup` first. If specific sections are missing, warn and proceed with what's available.

- **Repo Map** — table of repos with paths and aliases (workspace only; single repo can skip)
- **Feature Design Docs** — where design docs live (for output location and checking prior work)

## Steps

### 1. Determine scope

Parse `$ARGUMENTS`:
- If it contains a ticket ID (e.g., `PROJ-123`) → run ticket lookup
- If it contains a repo alias (workspace only) → limit research to that repo (match against Repo Map in CLAUDE.md)
- Otherwise treat the entire argument as a topic description

**Ticket lookup** (skip if no ticket ID):

Use any available MCP tools to look up the ticket (e.g., Linear, Jira, Glean). These are optional — if unavailable, skip and inform the user.

Present what was found. Use `AskUserQuestion` to let the user choose:
- Option A: "Proceed" — start exploring the codebase
- Option B: "Add context" — provide additional context before exploring

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

### 3. Research — Phase 1: Breadth scan

Identify all relevant areas across the codebase.

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
6. Entry points and callers — what triggers the relevant code paths
7. Downstream effects — what depends on this code's output
8. Risks or gotchas
```

### 4. Research — Phase 2: Deep dive

Based on Phase 1 findings, trace the full upstream/downstream relationship chains.

Spawn **subagents** (parallel where independent) to deep-dive specific areas identified in Phase 1. Each subagent focuses on one concern:

**Subagent A — Data flow tracing:**
```text
Trace the complete data flow for [topic] in <repo-path(s)>.

Starting from the entry points identified:
[list entry points from Phase 1]

For each entry point, trace:
1. Where does the input come from? (API request, CLI arg, queue message, cron, etc.)
2. What transformations happen along the way? (validation, mapping, enrichment)
3. What external systems are called? (DB queries, API calls, message publishing)
4. Where does the output go? (response, DB write, event, side effect)
5. What error paths exist? (retries, fallbacks, dead letters)

Return the full chain as a numbered sequence, with file:line references.
```

**Subagent B — Dependency mapping:**
```text
Map the dependency relationships for [topic] in <repo-path(s)>.

Starting from the key files identified:
[list key files from Phase 1]

For each file/module:
1. What does it import/depend on? (internal modules, external packages)
2. What imports/depends on it? (callers, consumers)
3. What shared state does it read or write? (DB tables, config, cache, global state)
4. What interfaces does it implement or expect?
5. Are there circular or complex dependency patterns?

Return a dependency list with direction (upstream/downstream) and file:line references.
```

**Subagent C — Interaction patterns** (spawn only if multiple services/repos are involved):
```text
Map the cross-boundary interactions for [topic].

Services/repos involved:
[list from Phase 1]

For each interaction:
1. Which service initiates? Which responds?
2. What protocol? (HTTP, gRPC, queue, shared DB, file)
3. What is the message/request format?
4. Is it sync or async?
5. What happens on failure? (timeout, retry, circuit breaker)
6. What ordering/consistency guarantees exist?

Return as interaction pairs with protocol and direction.
```

### 5. Write task.md

Read CLAUDE.md for the **Feature Design Docs** section to determine the design doc directory (default: `docs/features/`).

Create the feature directory if it doesn't exist, and write `task.md` using the [task template](../_shared/templates/task.md).

Adapt the template to what was actually found:
- Skip diagram sections that don't apply (e.g., no sequence diagram for single-service changes)
- Add extra diagrams if the data flow is complex (e.g., separate diagrams for happy path vs error path)
- Use the simplest diagram type that conveys the relationship clearly

Commit:
```bash
git add <task.md-path>
git commit -m "task(<ticket>): research findings"
```

### 6. Present summary

Show a concise summary in the conversation — do NOT repeat the full document. Focus on:
- Key findings that might surprise the user
- Open questions that need answers before `/spec`
- Risks worth discussing

Tell the user the document path so they can review the full details. When the discussion converges, suggest `/spec` to capture the design.

## Tips

- Keep findings factual — report what exists, don't propose solutions (that's discussion + `/spec`)
- Reference code by file path and line range, not by pasting large blocks
- If a repo is clearly not relevant, say so briefly rather than forcing a finding
- The user may run `/task` multiple times with different filters as discussion narrows scope
- Mermaid diagrams should be simple and readable — avoid cramming everything into one diagram
- Phase 2 subagents can be skipped for trivial tasks — use judgment based on Phase 1 complexity
