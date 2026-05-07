# Global Conventions

- Commit format: conventional commits `type(scope): message`, small and frequent commits
- PR title: `[TICKET-ID] type(scope): message` — omit `[TICKET-ID]` if none
- Comments only when the _why_ is non-obvious
- For non-trivial changes, write tests first (TDD).
- Use three-dot diff (`git diff A...B`) when comparing branch changes.
- Push rejected by remote: rebase onto latest and retry. If conflicts are unclear, ask the user.

# Tool Usage

- Avoid `cd <dir> && <cmd>` — use absolute paths or tool flags (`git -C`, `grep <path>`) instead.
- Use Read/Edit/Write tools instead of `cat`, `sed`, `awk`, `head`, `tail` in Bash.
