"""Hermes AgentMail poller — cron pre-run script.

Lists unhandled inbound messages across all AgentMail inboxes and prints
them as plain text for the Hermes agent to triage. When there is no new
mail it prints NOTHING, so the cron wake-gate skips the LLM entirely and
the tick costs zero tokens (see cron/scheduler.py:_build_job_prompt).

Dedup is label-based: a message tagged ``@handledLabel@`` is skipped. The
agent adds that label after handling each message, so a failed handling
run simply re-surfaces the mail next tick instead of dropping it.

Stdlib only — runs under the gateway venv's Python inside the container.
``AGENTMAIL_API_KEY`` is read from the gateway environment at run time.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://api.agentmail.to/v0"
HANDLED_LABEL = "@handledLabel@"
MAX_PER_RUN = @maxPerRun@
BODY_CHARS = 1500
LIST_LIMIT = 50
TIMEOUT = 30

# Labels marking a message as outbound or already triaged — never surface these.
SKIP_LABELS = {"sent", "draft", "trash", HANDLED_LABEL.lower()}

# Emitted as the only stdout line to keep the agent asleep without looking
# like an empty (no-mail) run. The cron wake-gate treats this as "skip".
_WAKE_OFF = json.dumps({"wakeAgent": False})


def _api_get(path):
    key = os.environ.get("AGENTMAIL_API_KEY", "").strip()
    if not key:
        print(_WAKE_OFF)
        sys.exit(0)
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        headers={"Authorization": f"Bearer {key}", "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _items(data, *keys):
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in keys:
            value = data.get(key)
            if isinstance(value, list):
                return value
    return []


def _list_inbox_ids():
    data = _api_get("/inboxes")
    ids = []
    for inbox in _items(data, "inboxes", "items"):
        iid = inbox.get("inbox_id") or inbox.get("id")
        if iid:
            ids.append(iid)
    return ids


def _list_messages(inbox_id):
    qs = urllib.parse.urlencode({"limit": LIST_LIMIT, "ascending": "false"})
    quoted = urllib.parse.quote(inbox_id, safe="")
    return _items(
        _api_get(f"/inboxes/{quoted}/messages?{qs}"), "messages", "items"
    )


def _get_message(inbox_id, message_id):
    quoted_inbox = urllib.parse.quote(inbox_id, safe="")
    quoted_msg = urllib.parse.quote(message_id, safe="")
    return _api_get(f"/inboxes/{quoted_inbox}/messages/{quoted_msg}")


def _should_surface(labels):
    present = {str(label).lower() for label in (labels or [])}
    return not (present & SKIP_LABELS)


def _collect():
    surfaced = []
    for inbox_id in _list_inbox_ids():
        if len(surfaced) >= MAX_PER_RUN:
            break
        try:
            messages = _list_messages(inbox_id)
        except urllib.error.URLError:
            continue
        for msg in messages:
            if len(surfaced) >= MAX_PER_RUN:
                break
            if not _should_surface(msg.get("labels")):
                continue
            message_id = msg.get("message_id") or msg.get("id")
            if not message_id:
                continue
            try:
                full = _get_message(inbox_id, message_id)
            except urllib.error.URLError:
                full = msg
            surfaced.append((inbox_id, message_id, full))
    return surfaced


def _render(surfaced):
    out = [f"{len(surfaced)} unhandled email(s) need triage:", ""]
    for i, (inbox_id, message_id, msg) in enumerate(surfaced, 1):
        sender = msg.get("from") or msg.get("sender") or "(unknown)"
        subject = msg.get("subject") or "(no subject)"
        when = msg.get("timestamp") or msg.get("created_at") or ""
        body = (msg.get("text") or msg.get("preview") or "").strip()
        if len(body) > BODY_CHARS:
            body = body[:BODY_CHARS] + "\n[... truncated ...]"
        out += [
            f"### Email {i}",
            f"- inbox_id: {inbox_id}",
            f"- message_id: {message_id}",
            f"- from: {sender}",
            f"- subject: {subject}",
            f"- date: {when}",
            "- body:",
            body,
            "",
        ]
    return "\n".join(out)


def main():
    try:
        surfaced = _collect()
    except Exception:
        # Fail safe: stay silent on any transient/API error rather than
        # waking the agent with a noisy "script failed" report every tick.
        print(_WAKE_OFF)
        return
    if surfaced:
        print(_render(surfaced))
    # No mail -> no output -> agent is not woken.


if __name__ == "__main__":
    main()
