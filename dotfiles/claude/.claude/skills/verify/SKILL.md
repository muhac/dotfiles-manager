---
description: Interactively verify a feature works end-to-end. Claude drives the verification — runs automated checks itself, gives manual commands to the user, analyzes results, and iterates.
when_to_use: When user says "verify", "test this", "check if it works", "validate the feature".
argument-hint: "[feature-or-topic]"
---

# Verify Feature

Interactively verify a feature works end-to-end. Claude drives the verification loop — runs automated checks itself, gives manual commands to the user, analyzes results, and iterates until everything passes or issues are identified.

## Usage

```text
/verify rf-0005                  # verify using design doc verification checklist
/verify the new login flow       # verify by topic (no design doc)
/verify                          # verify whatever was just implemented in this session
```

$ARGUMENTS

## Prerequisites

This skill optionally reads from CLAUDE.md:

- **Feature Design Docs** — where design docs live (for finding verification checklists)
- **Repo-Specific Conventions** — convention doc paths (for build/test/lint commands)

Works without CLAUDE.md — will ask what to verify instead.

## Steps

### 1. Determine what to verify

Parse `$ARGUMENTS`:
- If it matches a feature/ticket ID → read the design doc's component specs for `## Verification` checklists
- If it's a topic description → ask the user what the expected behavior is
- If empty → look at the current conversation context for what was just implemented

Gather:
- **What was changed** — `git diff` or recent commits on the current branch
- **Expected behavior** — from design docs, conversation context, or user description
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

## Tips

- Keep commands copy-pasteable — include the full command, not just a description
- For manual checks, always state what "success" looks like so the user knows what to compare against
- If the user pastes a large error output, focus on the root cause, not every line
- Don't re-run passing automated checks after fixing a different check, unless the fix could cause regressions
- If verification uncovers a bug, fix it and commit before continuing — don't accumulate unfixed issues
