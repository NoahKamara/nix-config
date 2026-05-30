---
name: agentmail
description: Send, receive, and manage email in pre-provisioned AgentMail inboxes via MCP. Not for the user's personal mail.
version: 1.0.0
platforms: [linux]
metadata:
  hermes:
    tags: [email, communication, agentmail, mcp]
    category: email
---

# AgentMail

[AgentMail](https://docs.agentmail.to/) is an email API for agents. Use it to read and send mail in the agent-owned inboxes that are already provisioned on this host — these are separate from the user's personal email. Operate only on existing inboxes; do not attempt to create or delete them.

The `agentmail` MCP server provides the tools below. Credentials are injected from the host.

## When to use

- Send email from one of the agent's inboxes
- Check for replies, verification codes, or other inbound mail
- Read and reply within an existing thread

## Tools

| Tool | Use |
|------|-----|
| `list_inboxes` | Find inbox IDs and addresses |
| `get_inbox` | Inbox details |
| `list_threads` | List threads in an inbox (how you see inbound mail) |
| `get_thread` | Full conversation and its messages |
| `send_message` | New outbound email |
| `reply_to_message` | Reply within a thread |
| `forward_message` | Forward a message |
| `update_message` | Set labels / status on a message |
| `get_attachment` | Download an attachment |

For docs on drafts, labels, scheduling, and other APIs, read [llms.txt](https://docs.agentmail.to/llms.txt) (append `.md` to any doc page URL for Markdown).

## Sending mail

1. Call `list_inboxes` to get the right `inbox_id`.
2. Call `send_message` with `inbox_id`, `to`, `subject`, and body.
3. Provide both `text` and `html` bodies when possible for better deliverability and rendering.

## Checking for new mail

There are no webhooks here — poll for inbound mail:

1. `list_inboxes` → pick the inbox.
2. `list_threads` on that inbox.
3. `get_thread` for any thread you need to act on.

## Replying

1. `get_thread` to read the conversation.
2. `reply_to_message` on the **latest** message in the thread.
3. Use `update_message` to adjust labels (e.g. remove `unreplied`) so you don't reply twice.

Use a message's `extracted_text` / `extracted_html` to get just the new reply body without quoted history.
