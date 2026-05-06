# Global Conventions

## Coding

- Commit format: `feat/fix/chore/refactor(scope): message`
- Short functions, clear naming, no dead code
- Comments only when the _why_ is non-obvious
- TDD: write tests first, then implement. Prefer integration tests over mocks.

## Workflow

- Feature workflow: `/setup → /task → /spec → /audit → /impl → /check → /cr → /fixcr`
- Debug: `/dig`
- Use subagents for context-heavy work (debug, review, research) — main context keeps structured results only
- Prefer selection-based interaction (AskUserQuestion) over free-text input
- Keep responses concise

## Review Standards

- Priority: correctness > security > performance > style
- Implementation must cover all spec items
- Don't add: excessive error handling, defensive coding for impossible cases, premature abstractions
