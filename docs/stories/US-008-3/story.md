# US-008.3: View New Supply Count per Breed

**Epic:** EPIC-008 — Market View
**Jira:** [PTS-60](https://igorrogachov9999.atlassian.net/browse/PTS-60)
**Priority:** High
**Labels:** `frontend`, `backend`

## User Story

As a Trader, I want to see how many new pets remain in supply per breed so that I can decide between supply and secondary market.

## Acceptance Criteria

- [ ] Supply count per breed visible in or alongside Market View
- [ ] Shows exact remaining count (e.g., "2 remaining")
- [ ] Count decrements in real-time as purchases are made by any trader
- [ ] Shows "Out of Stock" when count reaches 0

## Business Rules

- Supply starts at 3 per breed; each retail purchase decrements the count by 1

## Dependencies

- Blocked by: US-002.2 (supply count updated on purchase)
- Blocks: US-008.4 (real-time market view updates)
