---
description: Addresses review feedback on a PR. Classifies items, plans fixes, executes as separate commits, drafts reply, and pushes.
when_to_use: When user shares a PR URL for fixing review comments, says "fix review", "address feedback", or has /cr or /review output in context to act on.
allowed-tools: Bash(git *) Bash(gh *)
argument-hint: "[pr-url] [reply]"
---

# Fix PR Review

Addresses review feedback on a PR: classify each item, plan fixes, execute them as separate commits, reply to reviewer, and push.

Review feedback can come from three sources:
- **GitHub reviewer comments** — fetched from the PR via `gh api`
- **`/cr` output** — the structured code review result already in the conversation context
- **`/review` output** — the built-in review result already in the conversation context

## Usage

```text
/fixcr https://github.com/org/repo/pull/123              # fetch reviewer comments from GitHub + fix
/fixcr https://github.com/org/repo/pull/123 reply        # draft reply only (no code changes)
/fixcr                                                    # use /cr or /review output already in context
/fixcr reply                                              # draft reply for /cr or /review output in context
```

$ARGUMENTS

## Steps

### 1. Gather review feedback

**Determine the input source:**

- If `$ARGUMENTS` contains a PR URL → **GitHub mode**: fetch reviewer feedback from GitHub
- If `$ARGUMENTS` is empty or only contains `reply` → **Context mode**: use the `/cr` or `/review` output already present in the conversation

**GitHub mode** — spawn a **subagent** to fetch and summarize PR data. Keep raw diffs out of the main context.

**Subagent prompt:**
```text
Fetch review feedback for PR <number> in <owner/repo>.

Run these commands:
- gh pr view <number> --repo <owner/repo> --json title,body,state,baseRefName,headRefName
- gh api repos/<owner/repo>/pulls/<number>/reviews --jq '.[] | select(.state != "PENDING") | "--- review \(.id) by \(.user.login) (\(.state)) ---\n\(.body)\n"'
- gh api repos/<owner/repo>/pulls/<number>/comments --paginate --jq '.[] | "--- inline \(.id) by \(.user.login) at \(.path):\(.line) ---\n\(.body)\n"'

Return a **structured list** of review items:
- Item number
- Reviewer
- File path and line (if inline)
- The review comment text
- Whether it's a question, suggestion, or required change

Do NOT include the PR diff. Do NOT include resolved comments.
```

**Context mode** — extract the numbered review items from the `/cr` or `/review` output in the current conversation. The PR and repo should be identifiable from the review output or the current git branch.

In both modes, also read the repo's `CLAUDE.md` for commit and style conventions.

### 2. Classify each review item

For each review item, determine:

| Classification | Meaning |
|---------------|---------|
| **fix** | Needs code change in this PR |
| **done** | Already addressed in a previous commit on this branch |
| **wont-fix** | Disagree, not a bug, or matches existing codebase conventions |
| **question** | Reviewer asked a question, no code change needed |
| **separate** | Valid but too large for this PR — needs separate component or ticket |

### 3. Plan fixes

Spawn a **subagent** to read the relevant source code and plan all fixes. Keep implementation details out of the main context.

**Subagent prompt:**
```text
Plan fixes for the following review items on branch <branch> in <repo-path>.

First, run `gh pr diff <number> --repo <owner/repo>` to see what changed in the PR.

Review items classified as "fix":
[paste fix items from step 2]

For each fix item:
1. Read the relevant source file(s) — use the PR diff to locate what changed
2. Plan the specific change: file path, line range, what to change (before/after)
3. Note if it needs a test change too
4. Note if it affects other files or interface contracts

Also check:
- Items classified as "done": find the commit that already addressed each one
- Items classified as "wont-fix": check codebase conventions to support the justification

Return a **structured list** — one entry per review item with the planned action.
```

For each **separate** item, reference the component spec or ticket (main agent handles this from context).

**CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.**

Present the full analysis to the user:

| # | Review point (1 line) | Classification | Planned action |
|---|----------------------|----------------|----------------|

For **fix** items, expand the planned action with the specific change details below the table.

Use `AskUserQuestion` to let the user choose:
- Option A: "Approve" — proceed with fixes
- Option B: "Revise plan" — describe changes to classifications or planned actions
- Option C: "Discuss" — ask questions before deciding

The user may ask questions without approving. Answer, then re-present the options. Do NOT move to step 4 until approved.

### 4. Execute fixes

Process fixes one at a time. For each fix:

**4a. Make the change** — read the relevant source files, then edit. Follow repo conventions.

**4b. Commit** — stage and commit immediately after each fix. Each fix is a **separate commit**. Follow the repo's commit message convention (check recent `git log` for style).

Do NOT batch multiple fixes into one commit. Do NOT push yet.

**4c. Verify and cross-change review (once, after all fixes)**

After all fix commits are made:

1. **Lint + test** — run the repo's lint + test commands as a regression check. Read `CLAUDE.md` or `Makefile` in the target repo for the correct commands. If anything fails: fix, commit the fix, re-run until green.

2. **Cross-change review** — review all fix commits together (`git diff` from before the first fix to HEAD). Check for:
   - Inconsistencies between fixes (e.g., one fix uses a pattern that conflicts with another)
   - Naming or style drift across changes
   - Missing updates in related code (e.g., a fix changed a function signature but a caller wasn't updated)
   
   If issues found: fix, commit, re-run lint+test.

### 5. Draft reply

After all fixes are committed (or if mode is `reply`), draft a reply addressing every review item:

- **fix**: "Fixed — [what was changed]." (past tense, concise)
- **done**: "Already addressed in [commit description]."
- **wont-fix**: Clear explanation — reference codebase conventions, existing patterns, or risk/reward reasoning
- **question**: Direct answer
- **separate**: "Scoped as [component name / ticket] — [1-line reason it's separate]."

Structure the reply with numbered items matching the reviewer's points.

**GitHub mode**: Use a single PR comment (not inline replies) unless the reviewer used inline comments — in that case, reply inline.

**Context mode**: Present the summary to the user as conversation output (no GitHub comment needed since the review was self-generated).

**CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.**

Present the reply draft. Use `AskUserQuestion` to let the user choose:
- Option A: "Approve and push" — post reply and push commits
- Option B: "Edit reply" — describe changes to the reply draft
- Option C: "Discuss" — ask questions before deciding

### 6. Push and post

After user approval:

```bash
git push origin <branch>
```

If push is rejected (remote has new commits), pull --rebase first, re-run tests, then push.

**GitHub mode only** — post the reply:
```bash
gh api repos/<owner/repo>/issues/<number>/comments -X POST -f body="<reply>"
```

Report: commits pushed, reply posted (if applicable), PR URL.

## Tips

- Read `CLAUDE.md` before editing — it defines formatting, test, and commit conventions
- When classifying as **wont-fix**, always have a concrete reason (existing codebase pattern, out of scope, low risk)
- If a fix touches interface contracts, warn the user that other components may need corresponding changes
