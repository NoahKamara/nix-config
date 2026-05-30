---
name: delegation
description: Todoist-based delegation inbox — label protocol for proactive task execution with user approval gates.
version: 1.0.0
platforms: [linux]
metadata:
  hermes:
    tags: [todoist, delegation, tasks, proactive, approval]
    category: productivity
---

# Delegation Inbox

Noah delegates tasks to you via Todoist labels. This skill defines the label
protocol and the rules you follow when executing delegated work.

Label and project names default to `delegated`, `approval-needed`, and the
Delegation project; the host may configure different values.

## When to use

- The delegation cron wakes you with output from the poll script.
- Noah mentions a delegated Todoist task in conversation.
- You spot work Noah might delegate and want to suggest it (see below) — not
  for arbitrary Todoist tasks outside this protocol.

## Todoist tools

Use the `todoist` MCP server:

| Tool | Use |
|------|-----|
| `get_tasks` / filter | Inspect tasks outside a cron run |
| `close_task` | Mark delegated work done |
| `update_task` | Add or remove labels |
| Add comment | Summarise actions, questions, or handoffs |

## Labels (state machine)

| Label / state | Meaning | Who sets it |
|---------------|---------|-------------|
| `delegated` | Noah handed this to you — execute it | Noah |
| `approval-needed` | Blocked on Noah's input or a human-only step | You |
| `human` | Marks the portion only Noah can do (always pair with `approval-needed`) | You |
| `suggested` | You propose work; Noah decides whether to delegate | You |
| *(task closed)* | Done — not a label | You or Noah |

The delegation poller surfaces open tasks with `delegated` and without
`approval-needed`.

## Execution rules

1. **Only act on `delegated` tasks.** Never execute a task that doesn't carry
   the `delegated` label. If you see a task without it, leave it alone.

2. **Do the work, don't describe it.** Use your tools to actually complete the
   task. Add a Todoist comment summarising what you did, then close the task
   (`close_task`).

3. **Human-only steps.** If a task (or sub-step) requires a physical action,
   in-person interaction, manual login you can't perform, or anything else only
   Noah can do:
   - Complete any automatable part first.
   - Add the `human` label and `approval-needed` (both — so the poller stops).
   - Add a comment stating **what** Noah must do and **why** you can't.
   - Do NOT close the task. Do NOT leave `delegated` without `approval-needed`
     — that causes the same task to resurface every poll tick.

4. **Gate on ambiguity or risk.** If the task is ambiguous, irreversible, has
   cost implications, or you're missing critical information:
   - Add a comment with your specific question (state exactly what you need and why).
   - Add `approval-needed` via `update_task`.
   - Do NOT close the task. Do NOT proceed with the action.

5. **One comment per gate.** Don't stack multiple approval comments on the same
   task. If you've already asked, wait. If Noah replied in comments but left
   `approval-needed`, read his reply — don't re-ask the same question.

6. **Respect project scope.** Only execute tasks in the configured delegation
   project. During execution, don't create new tasks there — Noah or the email
   triage loop handle inbound task creation. Proactive suggestions (below) are
   the exception.

## When suggesting tasks proactively

When you (via a discovery cron or during conversation) identify something Noah
should consider delegating:

- Create the task in the delegation project with a clear, actionable title.
- Add the label `suggested` (not `delegated` — Noah decides what to delegate).
- Add a Todoist comment explaining why you're suggesting it.
- Do NOT add `delegated` yourself. Wait for Noah to label it.

## Telegram notifications

The delegation cron delivers summaries to Telegram. Keep them terse:

- One line per task: title + outcome (completed / needs-approval / human-handoff).
- If tasks needed approval or human action, still send the summary so Noah knows
  what's waiting on him.
- Respond with exactly `[SILENT]` (and nothing else) only when the poll queue
  was empty.
