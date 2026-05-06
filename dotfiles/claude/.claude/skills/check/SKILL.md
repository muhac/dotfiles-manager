---
description: Interactively check a feature works end-to-end. Claude drives the checking — runs automated checks itself, gives manual commands to the user, analyzes results, and iterates.
when_to_use: When user says "verify", "test this", "check if it works", "validate the feature".
allowed-tools: Bash(git *) Bash(gh *)
argument-hint: "[feature-or-topic]"
---

# Check Feature

Interactively check a feature works end-to-end. Claude drives the verification loop — runs automated checks itself, gives manual commands to the user, analyzes results, and iterates until everything passes or issues are identified.

## Usage

```text
/check rf-0005                   # check using design doc verification checklist
/check the new login flow        # check by topic (no design doc)
/check                           # check whatever was just implemented in this session
```

$ARGUMENTS

## Prerequisites

This skill optionally reads from CLAUDE.md:

- **Feature Design Docs** — where design docs live (for finding verification checklists)
- **Repo-Specific Conventions** — convention doc paths (for build/test/lint commands)

Works without CLAUDE.md — will ask what to check instead.

## Steps

### 1. Determine what to check

Parse `$ARGUMENTS`:
- If it's a topic description → ask the user what the expected behavior is
- If empty → look at the current conversation context for what was just implemented
- If it matches a feature/ticket ID → spawn a **subagent** to extract verification items from design docs. Keep spec content out of main context.

**Subagent prompt** (only for feature/ticket ID):
```text
Read the design docs for feature <ticket>.

1. Find the feature directory in the design doc location from CLAUDE.md
2. Read the feature README and all component specs
3. Extract every item from `## Verification` checklists across all specs
4. Run `git diff origin/<default-branch>...HEAD` to see what changed on this branch
5. Read the repo's CLAUDE.md for test/lint/build commands

Return:
- A flat list of verification items (from specs + standard test/lint)
- A summary of what files changed (paths only, not content)
- The repo's test/lint commands
```

For topic or empty mode, gather context directly:
- **What was changed** — `git diff origin/<default-branch>...HEAD` or recent commits on the current branch
- **Expected behavior** — from conversation context or user description
- **Existing test/lint commands** — from the repo's CLAUDE.md

### 2. Build verification plan

Create an ordered list of checks. For each check, classify it:

| Type | When | Example |
|------|------|---------|
| **auto** | Claude can run it directly — no external state, credentials, or interactive input needed | `go test ./...`, `make lint`, `go build` |
| **manual** | Needs a running server, external service, browser, interactive input, or credentials Claude doesn't have | `cresta agent chat`, `curl localhost:8080/health`, browser test |

Order: automated checks first (fast feedback), then manual checks.

Present the plan to the user. Use `AskUserQuestion`:
- Option A: "Start" — begin verification
- Option B: "Adjust" — add, remove, or reorder checks

### 3. Execute checks

Process checks one at a time.

**Auto check:**
1. Run the command
2. If pass → report ✅ and move to next
3. If fail → show the error, diagnose the root cause
4. Use `AskUserQuestion`: "Fix and re-verify" / "Skip" / "Stop"
5. If fix: make the change, commit, re-run the check

**Manual check:**
1. Present the command to run and what the expected output should look like
2. If the command has setup prerequisites (e.g., "start the server first"), list those too
3. Wait for the user to paste the result
4. Analyze the result against expected behavior
5. If pass → report ✅ and move to next
6. If fail → diagnose, suggest fix. Use `AskUserQuestion`: "Fix and re-verify" / "Skip" / "Stop"

After each check, show progress: `[3/7] ✅✅✅⬜⬜⬜⬜`

### 4. Summary

After all checks complete (or user stops early), show a summary:

```
## Verification Results

| # | Check | Type | Result |
|---|-------|------|--------|
| 1 | Unit tests pass | auto | ✅ |
| 2 | Lint clean | auto | ✅ |
| 3 | Server starts | manual | ✅ |
| 4 | Agent chat works | manual | ❌ — timeout on RF bridge |

Passed: 3/4
Issues found: 1 (details above)
```

If all pass, say so. If issues remain, summarize what needs fixing.

### 5. Pull request

First check if a PR already exists for the current branch (`gh pr view --json url`). If one exists, show the URL and skip this step.

Otherwise, use `AskUserQuestion`:
- Option A: "Open PR" — create a PR with `gh pr create`
- Option B: "Draft PR" — create a draft PR with `gh pr create --draft`
- Option C: "Skip" — no PR

If the user chooses to create a PR, spawn a **subagent** to generate the PR title and body:

```text
Generate a PR title and body for branch <branch> targeting <default-branch>.

1. Run `git log <default-branch>..<branch> --oneline` to see all commits
2. Run `git diff <default-branch>...<branch> --stat` for a file summary
3. Read the repo's CLAUDE.md for context

Return:
- A PR title (under 70 characters)
- A PR body in this format:
  ## Summary
  <bullet points summarizing the changes>

  ## Test plan
  [Bulleted checklist of how this was verified]
```

Create the PR:
```bash
gh pr create --title "<title>" --body "<body>"        # or --draft for draft PR
```

Report the PR URL.

## Tips

- Keep commands copy-pasteable — include the full command, not just a description
- For manual checks, always state what "success" looks like so the user knows what to compare against
- If the user pastes a large error output, focus on the root cause, not every line
- Don't re-run passing automated checks after fixing a different check, unless the fix could cause regressions
- If verification uncovers a bug, fix it and commit before continuing — don't accumulate unfixed issues
