---
description: Implements feature components using design docs. Reads design doc location and project structure from CLAUDE.md.
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(gh *)
argument-hint: "[ticket] [component] [fix]"
---

# Implement Feature

Implements feature components using design docs. Reads design doc location and project structure from CLAUDE.md.

## Usage

```text
/impl PROJ-123               # all `pending` or `in_progress` components
/impl PROJ-123 02            # only component 02
/impl PROJ-123 ..03          # all pending up to 03 (inclusive)
/impl PROJ-123 fix 02        # modify already-completed component 02
```

$ARGUMENTS

## Prerequisites

This skill reads the following from CLAUDE.md. If CLAUDE.md doesn't exist, suggest running `/setup` first.

- **Repo Map** — repos, paths, default branches (workspace only; single repo can skip)
- **Feature Design Docs** — where design docs live, directory naming convention
- **Git Rules** — branch naming, commit format, submodule conventions
- **Repo-Specific Conventions** — convention doc paths (workspace only; single repo uses its own CLAUDE.md)

## Steps

### 1. Parse request and read design docs

Determine the **feature name** and **mode** from `$ARGUMENTS`. Read CLAUDE.md for the design doc directory. If the feature name is ambiguous, read the feature index file and ask.

**Workspace check** — for workspaces (multi-repo with submodules), ensure all repos are initialized:
```bash
git -C <repo-path> rev-parse --git-dir    # one per repo, parallel
```
If any fails, run `git submodule update --init --recursive`.

For single-repo projects, skip this step.

Read the feature's `README.md` for shared context. Then spawn a **subagent** to read component specs and extract metadata — keep spec full text out of the main context.

**Subagent prompt:**
```text
Read the component specs in <design-doc-directory>/ and extract metadata.

Mode: <mode> (determines which specs to read)
| Mode | Syntax | Which specs to read |
|------|--------|-------------------|
| all | `PROJ-123` | all specs, skip `completed` and `on_hold` |
| single | `PROJ-123 02` | spec 02 only |
| through | `PROJ-123 ..03` | specs 01–03, skip `completed` and `on_hold` |
| fix | `PROJ-123 fix 02` | spec 02 (regardless of status) |

For each component spec, return ONLY this structured metadata:
- component number and name
- repo, branch, status
- parallel_with, depends_on
- runtime_inputs (if any)
- one-line summary of what it implements

Do NOT return the full spec content.
```

### 2. Build execution plan

Group components into **waves** based on dependency graph:

- Wave 1: components with `depends_on: []` (no dependencies)
- Wave 2: components whose dependencies are all in Wave 1
- Wave N: components whose dependencies are all in earlier waves
- Within each wave, components with matching `parallel_with` run as parallel subagents
- **Workspace**: components targeting the same repo must NOT be in the same wave (they share one working tree)
- **Single repo**: all components share the same working tree, so only one subagent can run at a time — waves are purely sequential

Skip components with `status: completed` or `on_hold` (except in fix mode). Components with `status: in_progress` are included — they indicate a previously interrupted execution.

**CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.**

Present the execution plan, then use `AskUserQuestion` to let the user choose:

**Question 1: Working mode** — suggest a branch name based on the ticket/feature name.
- Option A: "Worktree: `<suggested-name>`" — creates an isolated worktree, keeps current working tree clean
- Option B: "Branch: `<suggested-name>`" — checks out a branch in the current directory
- Option C (Other): user specifies a custom name

**Question 2: Approve plan**
- Option A: "Approve" — proceed with execution
- Option B: "Revise" — describe changes to the plan

If the user chooses **worktree**, use `EnterWorktree` with the chosen name before branch setup (3a). All subsequent work happens in the worktree. Skip the branch checkout steps in 3a — the worktree already has its own branch.

### 3. Execute waves

For each wave, execute the following sub-steps:

**3a. Branch setup**

For each component in the wave, spawn one **subagent per repo** in parallel (single repo: one subagent for the current repo). Determine default branches from Repo Map in CLAUDE.md (workspace) or `git symbolic-ref refs/remotes/origin/HEAD` (single repo).

```text
Set up branch <branch> in <repo-path> for development.

1. git fetch origin
2. Check if remote branch exists: git ls-remote --exit-code origin refs/heads/<branch>
3. If remote exists:
   - Checkout the branch (create local tracking branch if needed)
   - Pull latest: git pull --rebase origin <branch>
4. If remote does NOT exist:
   - If local branch exists, check for unmerged changes:
     git diff origin/<default-branch> <branch> --quiet
     (Use no-dot git diff to compare tree content, not git log — squash merge
     creates new commit hashes but the tree content matches)
   - If local branch has unmerged changes (exit code 1): STOP and report the --shortstat
   - If local branch is clean (exit code 0, content matches default branch): delete it
   - Create new branch from origin/<default-branch>
   Note: if currently on the target branch, run `git checkout origin/<default-branch> --detach` before deleting

Report: "ready" with current HEAD, or "blocked: local branch has unmerged changes" with shortstat
```

If any subagent reports "blocked", use `AskUserQuestion` to let the user choose:
- Option A: "Keep and push" — push the existing branch first, then continue
- Option B: "Discard and recreate" — delete the local branch and create a fresh one

**3b. Mark in progress**

Update each component spec: set `status: in_progress`. Commit:
```bash
git add <design-doc-directory>
git commit -m "status(<ticket>): mark component NN in_progress"
```

**3c. Pre-flight check**

Check the component's `runtime_inputs` from metadata. For each declared input, ask the user for the value before proceeding.

**3d. Implement**

Spawn one **general-purpose subagent per component** (parallel if multiple). The main agent should NOT implement directly — keep implementation details out of the main context.

```text
Implement component NN of feature <ticket> using TDD.

Runtime inputs: [paste resolved values from 3c. Omit if none.]

1. Read <design-doc-directory>/README.md for shared context
2. Read <design-doc-directory>/NN-*.md for the component spec
3. Read the repo's CLAUDE.md and any convention docs for build/test/lint commands and style rules

TDD cycle:
4. Write tests first — derive test cases from the spec's "What to implement", "Interface contracts", and "Verification" sections. Cover: interface contracts, expected inputs/outputs, error cases, boundary conditions.
5. Run the tests — confirm they FAIL (red). If any pass unexpectedly, the test may be wrong — investigate before proceeding.
6. Implement the changes described in "What to implement" and "How to implement". Follow the interface contracts exactly.
7. Run the tests again — confirm they PASS (green). Fix implementation until green.
8. Add any additional tests discovered during implementation — internal logic, integration paths, or edge cases not apparent from the spec alone.

Finalize:
9. Run full test suite and linting (read the repo's CLAUDE.md for commands)
10. If anything fails: fix, commit the fix, and re-run until green
11. Commit with an appropriate message
12. Report: files changed, commit hash, test/lint results, any issues
```

Do not proceed to review with failing tests.

After all subagents return, update each component spec's `## Verification` checklist — mark each item as `- [x]` that passed. Commit:
```bash
git add <design-doc-directory>
git commit -m "status(<ticket>): update component NN verification checklist"
```

**3e. Review (per-wave, focus on details)**

Spawn an **Explore agent** to review this wave's changes:

```text
Review the changes from wave N of feature <ticket>.

For each repo in this wave, run `git -C <repo-path> diff origin/<default-branch>..<branch>` to see changes.
Read the component spec(s) for this wave.

Focus on code-level details and return a **structured list** (not prose):
1. Error handling and edge cases
2. Naming consistency and code style
3. Test quality and coverage
4. Interface contract consistency (for parallel components: do signatures, types, endpoints match across boundaries?)
5. Any deviations from the component spec
```

**CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.**

Show the user:
- Files changed per repo
- Test results
- Review issues found (if any)

Use `AskUserQuestion` to let the user choose:
- Option A: "Approve" — proceed to next wave
- Option B: "Fix issues" — describe issues to address
- Option C: "Discuss" — ask questions before deciding

If fixes are needed: apply fixes, re-run 3d and 3e, checkpoint again.

**3f. Update spec**

Set status to `completed`. If the implementation deviated from the spec, update the spec to match. Commit:
```bash
git add <design-doc-directory>
git commit -m "status(<ticket>): mark component NN completed"
```

**3g. Repeat** for the next wave.

### 4. Finalize

After all waves complete:

- Update the feature index if all components are done

**4a. Full verify**

Run tests and linting for **all repos** modified across all waves. Spawn one **subagent per repo** in parallel:

```text
Run tests and linting for <repo-path>.

1. Read the repo's CLAUDE.md for test/lint commands
2. Run tests and linting
3. If anything fails: fix, commit, re-run until green
4. Report: pass/fail, what was fixed (if anything)
```

**4b. Review agent (holistic, focus on completeness)**

Spawn an **Explore agent** to review the full feature:

```text
Review the full implementation of feature <ticket>.

For each repo with changes, run `git -C <repo-path> diff origin/<default-branch>..<branch>`.
Read the feature README for the design spec.

Produce a **structured review report** (not prose):
1. Feature completeness: are all components wired together end-to-end?
2. Interface integration: do the contracts between components actually connect (across repos, services, or modules)?
3. Missing pieces: anything in the design spec that wasn't implemented?
4. Test coverage gaps across the full feature path
5. Suggested improvements (if any)
```

**CHECKPOINT — HARD GATE. Do NOT proceed until the user explicitly selects "Approve" via `AskUserQuestion`.**

Present the review report:
- Review findings
- All repos with committed changes and their branches

Use `AskUserQuestion` to let the user choose:
- Option A: "Approve and push" — push all branches
- Option B: "Fix issues" — describe issues to address
- Option C: "Discuss" — ask questions before deciding

If fixes are needed: apply, re-run 4a and 4b, checkpoint again.

**4c. Push**

**Workspace**: push each modified submodule repo, then push the workspace repo (design doc status updates):
```bash
git -C <repo-path> push -u origin <branch>    # one per submodule, parallel
git push -u origin HEAD                        # workspace repo
```

**Single repo**: just push once:
```bash
git push -u origin <branch>
```

**4d. Pull request**

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
3. Read the feature README at <design-doc-directory>/README.md for context

Return:
- A PR title (under 70 characters, summarizes the feature/change)
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

## Fix Mode

When invoked with `fix NN`:

- Does NOT skip based on status — works on completed components
- Uses the same branch setup (3a), status tracking (3b/3f), and wave/checkpoint flow
- Only executes the single specified component
- If the fix affects interface contracts, warn the user that dependent components may need updates

## Interruption Recovery

If a previous run was interrupted (components with `status: in_progress`):

1. For each involved repo, check for local work:
   - Uncommitted changes: `git -C <repo-path> status`
   - Unpushed commits: `git -C <repo-path> diff origin/<default-branch>... --shortstat`
2. If either exists, show a summary. Use `AskUserQuestion`:
   - Option A: "Continue" — resume from where it left off
   - Option B: "Discard and restart" — discard local work and start fresh
3. Resume from the interrupted wave — completed components are skipped automatically

## Tips

- Each implementation subagent reads the feature README, its component spec, and convention docs on its own — no need to paste content into the prompt
- In workspaces: code changes commit to submodule repos, status updates commit to the workspace repo
- Always verify interface contracts after parallel subagents return — they can't see each other's work
- When in doubt about a subagent's output, read the changed files directly before approving
