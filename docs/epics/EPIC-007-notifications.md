# EPIC-007: Real-Time Notifications

> **Epic ID:** EPIC-007
> **Priority:** Must Have
> **Status:** Ready for Development

---

## Summary

Each trader receives a private, chronological notification feed for all bid and trade events that involve them. Notifications are pushed in real-time and include the event type, pet breed, dollar amount, and the counterparty trader. Notifications persist for the session and are visible only to the recipient.

---

## End-to-End Workflow

```
Event Occurs (bid placed / accepted / rejected / withdrawn / outbid) → Backend Generates Notification → Pushed to Recipient's Panel → Appears in Notification Feed → Persists for Session Duration
```

---

## Notification Types

| Event | Recipient | Template |
|-------|-----------|----------|
| Bid placed on my listing | Seller | "New bid of $X from [Trader] on [Breed]" |
| My bid was accepted | Buyer | "Bid accepted — [Breed] purchased from [Seller] for $X" |
| I sold a pet | Seller | "Trade completed — [Breed] sold to [Buyer] for $X" |
| My bid was rejected | Buyer | "Your bid of $X on [Breed] was rejected by [Seller]" |
| My bid was withdrawn by me | — | No notification to self |
| I withdrew my bid | Seller | "Bid of $X on [Breed] withdrawn by [Trader]" |
| I was outbid | Previous bidder | "Your bid of $X on [Breed] was outbid by [Trader] ($Y)" |
| Listing withdrawn (had my bid) | Buyer | "Your bid of $X on [Breed] was rejected (listing withdrawn by [Seller])" |

---

## User Stories

### US-007.1 — Receive Event Notifications
> As a Trader, I want to receive real-time notifications for all events that affect my listings and bids so that I can respond promptly.

**Acceptance Criteria:**
- [ ] All 5 notification types delivered: bid received, bid accepted, bid rejected, bid withdrawn, outbid
- [ ] Each notification includes: event type, pet breed, dollar amount, counterparty trader name
- [ ] Notification appears within 2 seconds of the triggering event
- [ ] Notification is private — only visible to the recipient trader
- [ ] Notification feed persists for the duration of the session (no auto-dismiss)

---

### US-007.2 — View Notification Feed
> As a Trader, I want to see my notifications in chronological order so that I can track what happened.

**Acceptance Criteria:**
- [ ] Notifications displayed in chronological order (most recent at top or bottom, consistently)
- [ ] Each notification shows: timestamp (or sequence), event description, amount, counterparty
- [ ] Unread notifications are visually distinguished (badge, bold, highlight)
- [ ] Notification feed accessible without leaving the trader panel

---

### US-007.3 — Notifications Are Private
> As a Trader, I want to ensure other traders cannot see my notifications so that my bid activity is private.

**Acceptance Criteria:**
- [ ] Switching trader panels does not show the previous trader's notifications
- [ ] Trader A's notification panel contains only events relevant to Trader A
- [ ] No shared/global notification view

---

## Business Rules

| ID | Rule |
|----|------|
| BR-007-001 | Notifications are private — delivered only to the relevant recipient |
| BR-007-002 | A seller does not receive a notification for their own withdrawal |
| BR-007-003 | A bidder does not receive a notification when they withdraw their own bid |
| BR-007-004 | All notification events include: event type, breed, amount, counterparty |
| BR-007-005 | Notifications are in-memory; they do not survive a server restart |

---

## Out of Scope

- Email or push notifications outside the UI
- Notification sound/audio alerts
- Dismissible notifications
- Notification preferences or filtering
- Notifications surviving server restart

---

## Dependencies

- EPIC-003 (listing withdrawal triggers notification)
- EPIC-004 (bid events trigger notifications)
- EPIC-005 (trade accept/reject triggers notifications)
