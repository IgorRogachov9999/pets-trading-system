---
name: Jira ticket workflow stages
description: How to manage Jira ticket status transitions throughout the development lifecycle
type: feedback
---

Always manage Jira ticket statuses according to this lifecycle. Transition IDs for project PTS are: Backlog=11, To Do=21, In Progress=31, In Review=41, Done=51.

| Stage | Jira Status | When to apply |
|-------|------------|---------------|
| Ticket created, ready for work | **To Do** (21) | Immediately after creating a ticket |
| Agent dispatched / actively coding | **In Progress** (31) | When the agent tool call is made |
| Code committed, PR open / ready for review | **In Review** (41) | When the agent commits files and the work is ready to be checked |
| PR merged and deployed | **Done** (51) | After merge and any required deployment |

**Why:** The user explicitly asked for this workflow so Jira boards accurately reflect real work state rather than everything sitting in Backlog.

**How to apply:**
- On `mcp__atlassian__jira_create_issue`: immediately follow with `mcp__atlassian__jira_transition_issue` to "To Do" (21)
- On `Agent` dispatch: transition affected ticket(s) to "In Progress" (31) in the same message
- When agent completes and has written files to disk: transition to "In Review" (41)
- Reserve "Done" (51) for when a PR is actually merged/deployed — do not use Done just because an agent finished writing code
