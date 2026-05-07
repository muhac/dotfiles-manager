---
name: cr
description: Spec-aware, convention-aware code review with structured output that /fixcr can consume. Multi-pass review using subagents for logic, spec compliance, and style.
when_to_use: When user says "code review", "review my changes", "review this branch", "cr", or wants a structured review before /fixcr.
allowed-tools: Bash(git *) Bash(cd * && git *) Bash(gh *)
argument-hint: "[pr-url | ticket-or-feature] [nit]"
---

# Code Review

Spec-aware, convention-aware code review that produces structured, numbered findings. Runs three focused review passes using subagents: logic/correctness, spec compliance, and style/conventions.

Output is designed for `/fixcr` context mode — run `/fixcr` immediately after to classify and fix findings.

## Usage

```text
/cr                                        # review current branch vs default branch
/cr https://github.com/org/repo/pull/123   # review a GitHub PR
/cr rf-0005                                # review with spec compliance (feature mode)
/cr rf-0005 nit                            # include nit-level findings
```

$ARGUMENTS

## Prerequisites

This skill optionally reads from CLAUDE.md:

- **Feature Design Docs** — where design docs live (required for spec compliance pass)
- **Repo-Specific Conventions** — convention doc paths (enriches style pass)
- **Repo Map** — repos and paths (workspace only)

Works without CLAUDE.md — spec compliance and convention passes will be shallower but still run.

## Steps

### 1. Determine scope and gather diff

Parse `$ARGUMENTS` to determine the input mode:

- If it contains a PR URL → **PR mode**
- If it matches a feature/ticket ID → **Feature mode** (branch diff + spec compliance)
- If empty → **Branch mode** (branch diff only)

Also check if `nit` is present — if so, include nit-severity findings in the output. Otherwise suppress nits.

**Branch mode** — determine default branch and get the diff:
```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'
git diff origin/<default-branch>... --stat
git diff origin/<default-branch>... --name-only
```

If there are no changes vs default branch, report "nothing to review" and stop.

**PR mode** — spawn a **subagent** to fetch PR metadata and diff. Keep raw diff out of main context.

**Subagent prompt:**
```text
Fetch PR data for PR <number> in <owner/repo>.

Run these commands:
- gh pr view <number> --repo <owner/repo> --json title,body,state,baseRefName,headRefName,files
- gh pr diff <number> --repo <owner/repo>

Return:
- PR title, base branch, head branch
- List of changed files with change type (added/modified/deleted) and line counts
- The full diff content (needed by review passes)

Do NOT summarize the diff — return it in full for downstream analysis.
```

**Feature mode** — same as branch mode for the diff, plus locate the feature's design docs:
1. Read CLAUDE.md for the design doc directory
2. Find the feature directory matching the ticket/feature argument
3. Record the paths of README.md and component spec files (do NOT read them here — pass 2 subagent reads them)

For all modes, also note:
- The list of changed files (paths only) — passed to all three review subagents
- Whether CLAUDE.md exists and where convention docs are

### 2. Run review passes

Spawn three **subagents in parallel**. Each reads the changed files directly and returns structured findings. Parallel execution is safe because all passes are read-only.

**Pass 1 — Logic & Correctness**

**Subagent prompt:**
```text
Review the following code changes for logic and correctness issues.

Branch: <branch> in <repo-path>
Default branch: <default-branch>
Changed files: [list of file paths]

Run `git diff origin/<default-branch>... -- <file>` for each changed file to see the diff.
Then read each changed file in full for context around the changes.

Review for:
1. Bugs — incorrect logic, off-by-one errors, nil/null dereferences, race conditions
2. Error handling — unchecked errors, swallowed exceptions, missing cleanup/defer
3. Edge cases — empty inputs, boundary values, concurrent access, large inputs
4. Security — injection, auth bypass, sensitive data exposure, unsafe deserialization
5. Resource management — leaks (connections, goroutines, file handles), missing timeouts
6. Dead code — unreachable branches, unused variables, redundant checks
7. Behavioral changes — any change in observable behavior vs the code before this branch (return values, side effects, error messages, event ordering, defaults). Do NOT assume subtle changes are acceptable. Flag every behavioral difference, even if it looks intentional.

For each finding, return:
- severity: error | warning | suggestion
- file: <path>
- line: <line-number or range>
- category: bug | error-handling | edge-case | security | resource | dead-code | behavioral-change
- finding: <one-line description>
- rationale: <why this is a problem, what could go wrong>
- suggestion: <how to fix it>

Only report real issues. Do NOT pad with praise or obvious observations.
Do NOT review style, naming, or conventions — that is a separate pass.
```

**Pass 2 — Spec Compliance**

**Subagent prompt:**
```text
Review the following code changes for spec compliance and completeness.

Branch: <branch> in <repo-path>
Default branch: <default-branch>
Changed files: [list of file paths]

<If feature mode>
Read the feature design docs:
- Feature README: <readme-path>
- Component specs: [list of spec paths]
Read each spec, then check the implementation against it.
</If feature mode>

<If branch/PR mode>
Look for any design docs, READMEs, or architectural docs referenced in the changed files
or nearby directories. Use whatever context is available.
</If branch/PR mode>

Also read the repo's CLAUDE.md for context.

Run `git diff origin/<default-branch>...` to see all changes.

Review for:
1. Missing features — spec items not implemented or only partially implemented
2. Interface mismatches — function signatures, types, API contracts that don't match spec or existing callers
3. Contract violations — cross-boundary interfaces that are inconsistent
4. Behavioral drift — implementation that works but deviates from spec intent
5. Missing tests — spec verification items that lack corresponding test coverage
6. Incomplete error paths — spec-defined error cases that aren't handled

For each finding, return:
- severity: error | warning | suggestion
- file: <path>
- line: <line-number or range>
- category: missing-feature | interface-mismatch | contract-violation | behavioral-drift | missing-test | incomplete-error-path
- finding: <one-line description>
- rationale: <what the spec says vs what the code does>
- suggestion: <how to fix it>

Only report real issues. If no design docs are found, focus on interface consistency
and test coverage — skip spec-specific checks.
```

**Pass 3 — Style & Conventions**

**Subagent prompt:**
```text
Review the following code changes for style and convention compliance.

Branch: <branch> in <repo-path>
Default branch: <default-branch>
Changed files: [list of file paths]

Read the repo's CLAUDE.md for project conventions.
<If convention docs exist>
Read convention docs: [list of convention doc paths]
</If>

Also look at surrounding code in each changed file to understand local patterns.

Run `git diff origin/<default-branch>...` to see all changes.

Review for:
1. Naming — variables, functions, types, files that don't follow project conventions
2. Patterns — deviations from established patterns in the codebase
3. Organization — code placed in wrong package/module, functions that belong elsewhere
4. Documentation — missing or incorrect comments on public APIs
5. Consistency — new code that contradicts patterns in the same file or package
6. Simplification — unnecessarily complex code that could be simplified

For each finding, return:
- severity: warning | suggestion | nit
- file: <path>
- line: <line-number or range>
- category: naming | pattern | organization | documentation | consistency | simplification
- finding: <one-line description>
- rationale: <why this matters, what convention it violates>
- suggestion: <how to fix it>

Reference the specific convention or existing pattern being violated.
Do NOT review logic or correctness — that is a separate pass.
```

### 3. Consolidate findings

After all three subagents return, merge their findings into a single numbered list.

**Ordering**: sort by severity (error → warning → suggestion → nit), then by file path, then by line number.

**Deduplication**: if two passes found the same issue, merge into a single finding and note both categories.

**Nit filtering**: if `nit` was NOT in `$ARGUMENTS`, remove all nit-severity findings. Note how many nits were suppressed.

### 4. Present findings

**CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.**

Present the review results:

```
## Code Review: <branch or PR title>

<N> files changed, +<added> -<removed>

### Findings

| # | Sev | File | Line | Category | Finding |
|---|-----|------|------|----------|---------|

### Details

**1. [error] path/to/file.go:42 — Nil pointer dereference when input is empty**
Category: bug (logic)
Rationale: ...
Suggestion: ...

[... one detail block per finding ...]

### Summary
- Errors: N | Warnings: N | Suggestions: N
[- Nits: N (suppressed — run with `nit` to include)]
```

Use `AskUserQuestion` to let the user choose:
- Option A: "Approve" — finalize findings (ready for `/fixcr`)
- Option B: "Filter" — remove or reclassify specific findings by number
- Option C: "Discuss" — ask questions about specific findings

If the user filters or discusses, update and re-present. Do NOT proceed until approved.

### 5. Output for /fixcr

After approval, output the final numbered findings in a clean format for `/fixcr` context mode:

```
## Review Findings — <branch or PR>

1. [error] path/to/file.go:42 — Nil pointer dereference when input is empty
   Category: bug | Rationale: ...

2. [warning] path/to/handler.go:15 — Error from DB query is silently ignored
   Category: error-handling | Rationale: ...

[... one per finding ...]

N findings: X errors, Y warnings, Z suggestions.
Run `/fixcr` to classify and fix.
```

Do NOT post to GitHub — `/fixcr` handles that.

## Tips

- Feature mode (with ticket argument) gives the deepest review — pass 2 checks every spec item against the implementation
- Branch/PR mode still runs all three passes, but spec compliance is limited to what can be inferred from nearby docs
- The `nit` flag is suppressed by default to keep findings actionable
- `/cr` is non-destructive — it only reads code, safe to run at any point
- After `/cr`, run `/fixcr` (no args) to consume the findings and fix them
