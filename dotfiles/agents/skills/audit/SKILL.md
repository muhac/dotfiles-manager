---
name: audit
description: Reviews design docs against the actual codebase before implementation. Catches wrong file paths, outdated interfaces, incorrect assumptions, and missing dependencies.
when_to_use: When user says "audit", "review the spec", "check the design", "sanity check before implementing".
allowed-tools: Bash(git *) Bash(cd * && git *)
argument-hint: "[ticket-or-feature]"
---

# Audit Design Docs

Reviews design docs against the actual codebase before implementation. Reads each component spec and verifies its assumptions — file paths exist, interfaces match, calling patterns are correct, dependencies are available. Reports issues so specs can be fixed before `/impl` starts.

## Usage

```text
/audit rf-0005                   # audit all component specs for a feature
/audit rf-0005 02                # audit only component 02
```

$ARGUMENTS

## Prerequisites

This skill reads the following from CLAUDE.md. If CLAUDE.md doesn't exist, suggest running `/setup` first.

- **Feature Design Docs** — where design docs live
- **Repo Map** — repos and paths (workspace only)

## Steps

### 1. Locate design docs

Parse `$ARGUMENTS` for feature name and optional component number.

Read CLAUDE.md for the design doc directory. Find the feature directory. If ambiguous, read the feature index and ask.

Identify the paths of the README and component spec files to audit. Do NOT read them in the main context — the Explore agents will read them directly.

### 2. Audit each component

For each component spec, spawn an **Explore agent** to verify against the codebase. Run agents in parallel for independent components.

**Agent prompt:**

```text
Audit component NN of feature <ticket> against the actual codebase.

Read the feature README at <readme-path> for shared context.
Read the component spec at <spec-path>.
Read the repo's CLAUDE.md for conventions.

Verify each claim in the spec against real code. Return a **structured list** of findings:

1. **File paths** — do files listed in "What to implement" and "Codebase analysis" exist? Are paths correct?
2. **Interfaces** — do function signatures, types, proto fields, CLI flags referenced in the spec actually exist and match? Check the real definitions.
3. **Calling patterns** — does the spec's "How to implement" describe the actual code flow? Are callers/callees correct?
4. **Dependencies** — are imports, packages, and modules the spec assumes available actually present?
5. **Contracts** — do cross-boundary contracts in the spec match what the other side actually exposes?
6. **Stale references** — anything in the spec that was renamed, moved, or deleted since the spec was written?

For each finding, report:
- ✅ Verified — spec matches code
- ⚠️ Warning — spec is vague or could be interpreted wrong
- ❌ Error — spec contradicts actual code (include what the spec says vs what the code actually is)

Do NOT suggest improvements to the spec's design. Only verify factual accuracy.
```

### 3. Present findings

Synthesize all agent results into a single report:

```
## Audit Results: <feature-name>

### Component 01 — <name>
- ✅ File paths verified (3/3)
- ❌ `rfbService.CreateRFB()` — spec says returns `(string, error)`, actual signature is `(*RFBResponse, error)` (go-servers/bot-server/internal/rfb/service.go:45)
- ⚠️ Spec references `cmd/agent_bridge.go` — file doesn't exist yet (greenfield, expected)

### Component 02 — <name>
- ✅ All checks passed

### Summary
| Component | ✅ | ⚠️ | ❌ |
|-----------|---|---|---|
| 01 | 5 | 1 | 1 |
| 02 | 4 | 0 | 0 |
```

If errors were found, suggest running `/spec <ticket> revise` to fix them before implementing.

No checkpoint gate — this is informational. The user decides whether to fix specs or proceed as-is.

## Tips

- Focus on factual accuracy, not design quality — this is not a design review
- Greenfield files (don't exist yet) are expected — flag as ⚠️ not ❌
- If a spec references code from another component that hasn't been implemented yet, note it but don't flag as error
- Run this after `/spec` and before `/impl` to catch issues early
- Can also run mid-implementation to re-audit specs that were revised
