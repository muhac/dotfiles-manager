# Code Conventions

- Before starting implementation, confirm the approach with the user — don't jump straight into coding.
- Once aligned, execute without unnecessary interruptions — only ask when genuinely blocked or facing a critical decision.
- Comments only when the _why_ is non-obvious.
- For non-trivial changes, write tests first (TDD).

# Git & PR Workflow

- Use conventional commits `type(scope): message`, keep commits small and frequent.
- When a feature is implemented and verified, commit immediately — don't leave finished work uncommitted.
- Format PR titles as `[TICKET-ID] type(scope): message` — omit `[TICKET-ID]` if none.
- Use three-dot diff (`git diff A...B`) when comparing branch changes.
- When push is rejected, rebase latest if <3 commits; otherwise merge latest. Ask on unclear conflicts.
- Before force pushing, require explicit user confirmation — never silently overwrite remote history or refs.

# Tool Usage

- Avoid `cd <dir> && <cmd>` — use absolute paths or tool flags (`git -C`, `grep <path>`) instead.
- Use Read/Edit/Write tools instead of `cat`, `sed`, `awk`, `head`, `tail` in Bash.
