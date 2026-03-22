# US-003.1: List a Pet for Sale

**Epic:** EPIC-003 — Secondary Market Listing Management
**Jira:** [PTS-40](https://igorrogachov9999.atlassian.net/browse/PTS-40)
**Priority:** High
**Labels:** `backend`, `frontend`

## User Story

As a Trader, I want to list a pet at an asking price so that other traders can bid on it.

## Acceptance Criteria

- [ ] Trader can initiate a listing from any unlisted pet in their inventory
- [ ] Asking price input is required; must be a positive number > $0
- [ ] Listed pet appears in the shared Market View immediately after creation
- [ ] Listed pet remains visible in trader's inventory (ownership not transferred)
- [ ] Pet is marked as "listed" with its asking price in the inventory view
- [ ] Asking price of $0 or negative is rejected with an error message
- [ ] A pet that already has an active listing cannot be listed again

## Business Rules

- BR-003-001: Only the pet's owner can create a listing for it
- BR-003-002: Asking price must be > $0
- BR-003-003: A pet can have at most one active listing at a time
- BR-003-006: Listed pet remains in seller's inventory until trade completes

## Dependencies

- Blocked by: US-001.1 (session initialized), US-002.2 (need pets in inventory)
- Blocks: US-003.2, US-003.3, US-004.1
