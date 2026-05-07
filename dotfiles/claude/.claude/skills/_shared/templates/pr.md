Generate a PR title and body for branch <branch> targeting <default-branch>.

1. Run `git log <default-branch>..<branch> --oneline` to see all commits
2. Run `git diff <default-branch>...<branch> --stat` for a file summary
3. Read the feature README or repo CLAUDE.md for context

Return:
- A PR title (under 70 characters, summarizes the feature/change)
- A PR body in this format:
  ## Summary
  <bullet points summarizing the changes>

  ## Test plan
  [Bulleted checklist of how this was verified]
