# Feature Name

## Problem
[What problem does this solve, why is it needed]

## Architecture
[Data flow and component interactions. Use text diagrams if helpful.
Workspace: describe data flow across repos.]

## Scope >>> WORKSPACE ONLY — omit for single repo <<<
[Which repos are involved and why. Which repos are NOT involved and why.]

## Interface Changes
[New or modified interfaces: CLI commands, API endpoints, SDK types,
proto definitions, config formats, UI pages/components, etc. Omit if none.]

## Interface Contracts
[Interfaces that must match across boundaries — repos, services, or modules.
Function signatures, message types, RPC names, CLI flags, shared types, etc.
Omit if the feature is self-contained within one module.]

## Component Overview
>>> WORKSPACE: use this table (with Repo column) <<<
| # | Component | Repo | Parallel | Dependencies | Description |
|---|-----------|------|----------|-------------|-------------|
>>> SINGLE REPO: use this table (without Repo column) <<<
| # | Component | Parallel | Dependencies | Description |
|---|-----------|----------|-------------|-------------|

## Related Features
[Links to related feature docs, if any. Omit if none.]

## Behavioral Changes
[Any difference between current behavior and new behavior. Do NOT omit
this section — if there are no behavioral changes, state that explicitly.
Do NOT assume subtle changes are acceptable. Every change in observable
behavior must be listed, no matter how minor, with:
- Current behavior (what happens today)
- New behavior (what will happen after this feature)
- Impact (who/what is affected, is it breaking)
- Resolution (accepted, needs migration, needs flag, needs discussion)]

## Design Decisions
[Key trade-offs and why this approach was chosen]
