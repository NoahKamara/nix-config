"""Hermes Todoist delegation poller — cron pre-run script.

Lists open Todoist tasks in the delegation project that carry the
``@delegatedLabel@`` label but NOT the ``@approvalLabel@`` label.
These are tasks the user has delegated and the agent should execute.

When the queue is empty the script prints NOTHING so the cron wake-gate
skips the LLM entirely (zero tokens on idle ticks).

Dedup is label-based: the agent completes tasks it finishes and flips
tasks needing approval to ``@approvalLabel@``, so the same task never
appears twice in consecutive runs.

Stdlib only — runs under the gateway venv's Python inside the container.
``TODOIST_API_KEY`` is read from the gateway environment at run time.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://api.todoist.com/rest/v2"
DELEGATED_LABEL = "@delegatedLabel@"
APPROVAL_LABEL = "@approvalLabel@"
PROJECT_NAME = "@projectName@"
MAX_PER_RUN = int("@maxPerRun@")
TIMEOUT = 30


def _api_get(path, params=None):
    key = os.environ.get("TODOIST_API_KEY", "").strip()
    if not key:
        sys.exit(0)
    qs = ("?" + urllib.parse.urlencode(params)) if params else ""
    req = urllib.request.Request(
        f"{API_BASE}{path}{qs}",
        headers={"Authorization": f"Bearer {key}", "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _collect():
    filter_str = f"@{DELEGATED_LABEL} & !@{APPROVAL_LABEL}"
    if PROJECT_NAME:
        filter_str = f"#{PROJECT_NAME} & {filter_str}"
    tasks = _api_get("/tasks", {"filter": filter_str})
    if not isinstance(tasks, list):
        return []
    return tasks[:MAX_PER_RUN]


def _get_comments(task_id):
    try:
        return _api_get("/comments", {"task_id": str(task_id)})
    except urllib.error.URLError:
        return []


def _render(tasks):
    out = [f"{len(tasks)} delegated task(s) ready for execution:", ""]
    for i, task in enumerate(tasks, 1):
        task_id = task.get("id", "")
        content = task.get("content", "(no title)")
        description = task.get("description", "").strip()
        due = task.get("due")
        due_str = due.get("string", due.get("date", "")) if due else ""
        labels = ", ".join(task.get("labels", []))
        url = task.get("url", "")

        comments = _get_comments(task_id)
        comment_text = ""
        if comments:
            recent = comments[-3:]
            comment_text = "\n".join(
                f"  [{c.get('posted_at', '')}] {c.get('content', '')}"
                for c in recent
            )

        out += [
            f"### Task {i}",
            f"- task_id: {task_id}",
            f"- content: {content}",
        ]
        if description:
            out.append(f"- description: {description}")
        if due_str:
            out.append(f"- due: {due_str}")
        if labels:
            out.append(f"- labels: {labels}")
        if url:
            out.append(f"- url: {url}")
        if comment_text:
            out += ["- recent comments:", comment_text]
        out.append("")
    return "\n".join(out)


def main():
    try:
        tasks = _collect()
    except Exception:
        # Fail safe: stay silent on transient/API errors rather than
        # waking the agent with noise every tick.
        return
    if tasks:
        print(_render(tasks))


if __name__ == "__main__":
    main()
