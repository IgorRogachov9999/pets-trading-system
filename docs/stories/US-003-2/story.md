# US-003.2: View Own Active Listings

**Epic:** EPIC-003 — Secondary Market Listing Management
**Jira:** [PTS-41](https://igorrogachov9999.atlassian.net/browse/PTS-41)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see all my active listings and their bid status so that I can manage them.

## Acceptance Criteria

- [ ] Seller can see all their currently listed pets and asking prices
- [ ] Seller can see whether a bid exists (yes/no indicator) on each listing
- [ ] Seller can view the bid amount and bidder when choosing to act on it
- [ ] Seller cannot see other traders' bid amounts from the Market View
- [ ] Listed pets are visually distinguished from unlisted pets in inventory

## Business Rules

- BR-003-005: Sellers see their own bid details; bid amounts not visible to other traders from Market View

## Dependencies

- Blocked by: US-001.1 (session initialized), US-002.2 (need pets in inventory)
- Blocks: _none_
