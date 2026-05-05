---
description: Addresses review feedback on a PR. Classifies items, plans fixes, executes as separate commits, drafts reply, and pushes.
when_to_use: When user shares a PR URL for fixing review comments, says "fix review", "address feedback", or has /review output in context to act on.
allowed-tools: Bash(git *) Bash(gh *)
argument-hint: "[pr-url] [reply]"
---

# Fix PR Review

Addresses review feedback on a PR: classify each item, plan fixes, execute them as separate commits, reply to reviewer, and push.

Review feedback can come from two sources:
- **GitHub reviewer comments** — fetched from the PR via `gh api`
- **`/review` output** — the self-review result already in the conversation context

## Usage

```text
/fixcr https://github.com/org/repo/pull/123              # fetch reviewer comments from GitHub + fix
/fixcr https://github.com/org/repo/pull/123 reply        # draft reply only (no code changes)
/fixcr                                                    # use /review output already in context
/fixcr reply                                              # draft reply for /review output in context
```

$ARGUMENTS

## Steps

### 1. Gather review feedback

**Determine the input source:**

- If `$ARGUMENTS` contains a PR URL → **GitHub mode**: fetch reviewer feedback from GitHub
- If `$ARGUMENTS` is empty or only contains `reply` → **Context mode**: use the `/review` output already present in the conversation

**GitHub mode** — parse the owner, repo, and PR number from the URL, then run in parallel:
```bash
gh pr view <number> --repo <owner/repo> --json title,body,state,baseRefName,headRefName
gh pr diff <number> --repo <owner/repo>
gh api repos/<owner/repo>/pulls/<number>/reviews --jq '.[] | select(.state != "PENDING") | "--- review \(.id) by \(.user.login) (\(.state)) ---\n\(.body)\n"'
gh api repos/<owner/repo>/pulls/<number>/comments --paginate --jq '.[] | "--- inline \(.id) by \(.user.login) at \(.path):\(.line) ---\n\(.body)\n"'
```

**Context mode** — extract the numbered review items from the `/review` output in the current conversation. The PR and repo should be identifiable from the review output or the current git branch. Run `gh pr diff` if the diff is not already in context.

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

For each **fix** item, read the relevant source code and plan the specific change:
- File path and line range
- What to change — concrete description or code snippet showing before/after
- Whether it needs a test change too
- Whether it affects other files or interface contracts

For each **wont-fix** item, prepare the justification (reference codebase conventions, existing patterns, or risk/reward reasoning).

For each **done** item, identify the commit that addressed it.

For each **separate** item, reference the component spec or ticket.

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
