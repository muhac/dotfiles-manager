---
name: walk
description: Interactively walks through a code path step by step. Guides the user through call chains, data flows, and request handling with explanations at each step.
when_to_use: When user says "walk me through", "explain the flow", "how does X work", "trace through", "show me how".
allowed-tools: Read Bash(git *) Bash(cd * && git *)
argument-hint: "[entry-point-or-topic]"
---

# Walk Through Code

Interactively walks through a code path step by step. Guides the user through call chains, data flows, and request handling — explaining what each piece does and why, at the user's pace.

## Usage

```text
/walk handleLogin                    # trace from a function
/walk src/auth/middleware.ts          # start from a file
/walk the checkout flow              # describe a feature/topic
/walk                                # use topic from conversation context
```

$ARGUMENTS

## Steps

### 1. Determine entry point

Parse `$ARGUMENTS` for a function name, file path, or topic description.

Spawn an **Explore agent** to locate the entry point:

```text
Find the entry point for [topic/function/file] in <repo-path>.

1. If a function name: find where it's defined (file:line)
2. If a file path: identify the main export or entry function
3. If a topic: find the most likely entry point (API handler, CLI command, event listener, etc.)

If multiple candidates exist, return all with one-line descriptions.

Return:
- Entry point(s): file:line, function name, one-line description
- Type of flow: request handling / data pipeline / event chain / CLI command / other
```

If multiple entry points are found, use `AskUserQuestion` to let the user pick.

### 2. Map the path

Spawn an **Explore agent** to scan the full code path from the entry point. Keep raw code out of the main context.

```text
Map the complete code path starting from <entry-point> in <repo-path>.

Trace the call chain / data flow from entry to exit. For each step:
1. File path and line number
2. Function or method name
3. One-line summary of what it does
4. Branch points: conditions where the flow splits (if/switch, error handling, async paths)

Follow the primary (happy) path. Note branch points but don't trace them yet.

Return an **ordered list** of steps:
- Step N: file:line — functionName — summary
- Branch points marked with: ⑂ [branch description]

Keep it to the main flow — don't recurse into utility functions or library internals unless they contain important logic.
```

### 3. Present overview

Show the user the path overview — numbered steps without code:

```
## Path Overview: [topic]

1. `src/auth/handler.ts:42` — handleLogin — receives login request, validates payload
2. `src/auth/service.ts:88` — authenticateUser — looks up user, verifies password
   ⑂ error: invalid credentials → returns 401
3. `src/auth/token.ts:15` — generateToken — creates JWT with user claims
4. `src/auth/handler.ts:67` — sendResponse — sets cookie, returns 200

4 steps · 3 files · 1 branch point
```

Use `AskUserQuestion`:
- Option A: "Start from beginning" — walk from step 1
- Option B: "Jump to step N" — start at a specific step
- Option C: "Adjust scope" — broaden or narrow the path

### 4. Walk step by step

For each step, spawn a **subagent** to read the code with full context and prepare an explanation:

```text
Explain step N of a code walkthrough in <repo-path>.

Step: <file:line — functionName — summary>
Previous step context: <what the previous step did and what it passed to this step>

1. Read the function/method at the specified location
2. Read enough surrounding context to understand it: imports, types, caller, callee signatures
3. Identify the key 10-30 lines that matter for this step

Return:
- **Code snippet**: the key lines (with file path and line numbers)
- **Explanation**: what this code does, WHY it does it this way (design decisions, constraints, patterns), and how it connects to the previous/next step
- **Key details**: important types, constants, config values that affect behavior
- **Branch points**: any conditions where the flow could diverge, with one-line description of each branch
```

Present the subagent's result to the user:
- Show the code snippet
- Show the explanation
- List available branches (if any)

Use `AskUserQuestion`:
- Option A: "Next" — continue to the next step
- Option B: "Deeper" — dive into a function/module called in this step
- Option C: "Branch: [name]" — follow an alternative path (error handling, edge case, etc.)
- Option D (Other): user asks a free-form question

**Handling each choice:**

- **Next**: advance to the next step in the path, repeat step 4
- **Deeper**: spawn a subagent to map the internals of the chosen function, then walk through it as a sub-path. When done, return to the current step and re-present the options.
- **Branch**: spawn a subagent to map the branch path, then walk through it. When done, return to the current step and re-present the options.
- **Question**: if the question needs more code context, spawn a subagent to look it up. Answer in the main context, then re-present the options for the current step.

**Stay on the current step until the user explicitly selects "Next".** Deeper, Branch, and Question all return to the same step afterwards.

### 5. Wrap up

When the user selects "Done" or the path is complete:

Summarize the full flow in one short paragraph — the core logic, key design patterns, and any gotchas worth remembering.

## Tips

- Each step's subagent reads full context (whole files, type definitions, callers) — but only returns the distilled explanation and a compact code snippet to the main context
- Don't over-explain obvious code — focus on the non-obvious: why this pattern, what constraint drove this choice, what would break if changed
- When the user goes "deeper", track the depth so you can navigate back: "Returning to main path, step 3"
- Keep code snippets short — if a function is 100 lines, show the 10-20 lines that matter for this step
- If the codebase has docs or comments explaining a design decision, quote them — they're the original author's intent
- This skill is read-only — no commits, no file changes, no branches
