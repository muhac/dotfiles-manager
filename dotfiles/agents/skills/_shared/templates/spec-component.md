# NN - Component Name

repo: <repo> or [repo1, repo2] if spanning multiple repos (omit for single repo)
branch: <branch-name>
status: pending | in_progress | completed | on_hold
parallel_with: [component numbers]
depends_on: [component numbers]

## Codebase analysis
[Existing code paths, key structures, and calling patterns relevant to this
component. Helps the implementer understand what exists before changing it.
Omit if the change is greenfield with no existing code to understand.]

## What to implement
[Files to create/modify with full paths]

## How to implement
[Key logic, pseudocode, patterns to follow — reference specific files
found during research]

## Interface contracts
[What this component produces or consumes from other components.
Function signatures, CLI flags, API endpoints, shared types that MUST match.
Omit if the component has no cross-boundary dependencies.]

## Runtime inputs
[Values only known after a prior component completes. Omit section if none.]
- name: <variable_name>
  from: component <NN>
  description: <what it is>

## Observability
[Logging, metrics, or alerting this component should add.
Omit if the change has no runtime behavior (e.g., pure refactor, proto-only).]

## Verification
- [ ] Linter passes
- [ ] Tests pass
- [ ] [Feature-specific checks]
