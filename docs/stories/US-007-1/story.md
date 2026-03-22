# US-007.1: Receive Event Notifications in Real-Time

**Epic:** EPIC-007 — Real-Time Notifications
**Jira:** [PTS-56](https://igorrogachov9999.atlassian.net/browse/PTS-56)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to receive real-time notifications for all events that affect my listings and bids so that I can respond promptly.

## Acceptance Criteria

- [ ] All 5 notification types delivered: bid received, bid accepted, bid rejected, bid withdrawn, outbid
- [ ] Each notification includes: event type, pet breed, dollar amount, counterparty trader name
- [ ] Notification appears within 2 seconds of the triggering event
- [ ] Notification is private — only visible to the recipient trader
- [ ] Notification feed persists for the duration of the session (no auto-dismiss)

## Notification Templates

- Bid placed on my listing: "New bid of $X from [Trader] on [Breed]"
- My bid was accepted: "Bid accepted — [Breed] purchased from [Seller] for $X"
- I sold a pet: "Trade completed — [Breed] sold to [Buyer] for $X"
- My bid was rejected: "Your bid of $X on [Breed] was rejected by [Seller]"
- I was outbid: "Your bid of $X on [Breed] was outbid by [Trader] ($Y)"
- Listing withdrawn (had my bid): "Your bid of $X on [Breed] was rejected (listing withdrawn by [Seller])"

## Business Rules

- BR-007-001: Notifications are private and scoped to the recipient trader only
- BR-007-002: Notifications are delivered in real-time (within 2 seconds of the triggering event)
- BR-007-003: All 5 trade event types generate notifications to the relevant parties
- BR-007-004: Notification feed persists for the session without auto-dismissal

## Dependencies

- Blocked by: US-003.3 (listing withdrawn event), US-004.1 (bid placed event), US-005.1 (bid accepted/trade completed events)
- Blocks: US-007.2 (notification feed display), US-007.3 (privacy enforcement)
