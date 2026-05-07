---
description: Debugs a problem by systematically narrowing down the root cause using subagents. Keeps raw traces and file content out of main context.
when_to_use: When user reports a bug, error, test failure, unexpected behavior, or says "dig", "debug", "investigate this error", "why is this failing".
allowed-tools: Bash(git *) Bash(cd * && git *) Bash(gh *)
argument-hint: "[symptom-or-error]"
---

# Dig Into Problem

Debugs a problem by systematically narrowing down the root cause. Uses subagents for heavy investigation to keep main context clean — raw stack traces, log output, and file reads stay in subagents.

## Usage

```text
/dig login API returns 500                    # describe the symptom
/dig TestUserCreate is failing                # failing test
/dig "panic: runtime error: index out of range"   # paste an error message
/dig                                          # use error/symptom already in conversation
```

$ARGUMENTS

## Prerequisites

This skill optionally reads from CLAUDE.md:

- **Repo-Specific Conventions** — build/test/lint commands
- **Repo Map** — repos and paths (workspace only)

Works without CLAUDE.md — will ask for test/build commands if needed.

## Steps

### 1. Gather symptoms

Parse `$ARGUMENTS` or extract from conversation context:

- **Error message** or stack trace
- **Failing test** name or output
- **Unexpected behavior** description
- **Reproduction steps** (if known)

If the symptom is unclear, ask the user to describe:
- What happened vs what was expected
- When it started (recent change? always broken?)
- Any relevant context (branch, environment, recent deploys)

Check if the problem is tied to a recent change:
```bash
git log --oneline -10
```

### 2. Locate relevant code

Spawn a **subagent** to map out the code paths involved. Keep file content out of main context.

**Subagent prompt:**
```text
Investigate the code paths related to this problem in <repo-path>.

Symptom: <symptom description>
<If stack trace> Stack trace: <paste stack trace> </If>
<If test name> Failing test: <test name> </If>

1. If a stack trace is provided, trace each frame to its source file
2. If a test name is provided, find the test and read it
3. Find the entry point for the failing behavior
4. Trace the code path from entry to the point of failure
5. Identify all functions and files in the critical path
6. Check recent changes to these files: `git log --oneline -5 -- <file>` for each

Return a **structured list**:
- Critical path: ordered list of files and functions from entry to failure point
- Recent changes: any recent commits touching these files (with hash and summary)
- Suspicious areas: code that looks likely to cause the reported symptom
- Dependencies: external services, configs, or data that this code path relies on
```

### 3. Form hypotheses

Based on the subagent's findings, form **2-3 hypotheses** ranked by likelihood:

| # | Hypothesis | Likelihood | How to verify |
|---|-----------|-----------|---------------|
| 1 | ... | high | ... |
| 2 | ... | medium | ... |
| 3 | ... | low | ... |

Present to the user. Use `AskUserQuestion`:
- Option A: "Investigate all" — verify hypotheses in order
- Option B: "Pick specific" — user selects which to investigate
- Option C: "Add hypothesis" — user suggests another possibility

### 4. Verify hypotheses

For each hypothesis, spawn a **subagent** to verify. Run sequentially — each result may eliminate or confirm a hypothesis, affecting whether to continue.

**Subagent prompt:**
```text
Verify this hypothesis about a bug in <repo-path>.

Hypothesis: <hypothesis description>
Verification approach: <how to verify>
Critical path files: [list from step 2]

Do the following:
1. Read the relevant source files
2. <verification-specific steps, e.g.:>
   - Add targeted logging and run the test
   - Check the specific condition that would cause this behavior
   - Read the test setup/fixtures for incorrect assumptions
   - Check config values or environment dependencies
3. Determine: CONFIRMED, RULED OUT, or INCONCLUSIVE

Return:
- Result: confirmed / ruled out / inconclusive
- Evidence: what you found that supports the conclusion
- If confirmed: the exact root cause (file, line, what's wrong)
- If inconclusive: what additional information would help
```

After each verification:
- **Confirmed** → proceed to step 5 (fix)
- **Ruled out** → try next hypothesis
- **Inconclusive** → report to user, ask for more context or suggest deeper investigation

If all hypotheses are ruled out, gather new information and return to step 3 with refined hypotheses.

### 5. Fix

Once root cause is confirmed:

**5a. Plan the fix**

Present the root cause and proposed fix to the user:

```
## Root Cause

<file>:<line> — <what's wrong and why>

## Proposed Fix

<what to change and why>
```

Use `AskUserQuestion`:
- Option A: "Fix it" — proceed with the fix
- Option B: "Different approach" — user suggests alternative
- Option C: "Just report" — don't fix, just document the finding

**5b. Implement and verify**

If the user approves the fix, spawn a **subagent** to implement:

**Subagent prompt:**
```text
Fix a bug in <repo-path>.

Root cause: <root cause description>
File: <file path>, line: <line number>
Fix: <what to change>

1. Read the file and understand the surrounding context
2. Read the repo's CLAUDE.md for conventions
3. Make the fix
4. Behavioral change check — verify the fix ONLY changes the broken behavior. If any other observable behavior changes (return values, side effects, error messages, defaults, etc.), STOP and report it before continuing.
5. If a test was failing, run it to confirm it passes now
6. Run the repo's test suite to check for regressions
7. Commit with an appropriate message

Report: what changed, test results, commit hash
```

If tests fail after the fix, report back and iterate.

### 6. Summary

Report the outcome:

```
## Diagnosis

Symptom: <original symptom>
Root cause: <file:line — what was wrong>
Fix: <what was changed> (commit <hash>)
Verification: <test results>
```

If the fix revealed related issues, mention them. Do NOT fix them unless asked — scope creep during debugging makes things worse.

## Tips

- The key value of this skill is context management — stack traces and file reads stay in subagents
- Start narrow: verify the most likely hypothesis first before expanding scope
- If a test is failing, read the test FIRST — the test itself might be wrong
- Check `git log` early — recent changes are the most common cause of new bugs
- Don't fix and investigate at the same time — confirm root cause before changing code
- If the user pastes a large error output, extract the key line and work from there
