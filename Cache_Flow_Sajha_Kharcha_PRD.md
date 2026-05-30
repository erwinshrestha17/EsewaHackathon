# Sajha Kharcha PRD

Team: Cache Flow
Challenge: Challenge 10 - Enabling Smart Group Expense Management for Shared Financial Activities
App name: Sajha Kharcha
Tagline: Connect, split, gift, and settle together inside eSewa.
Version: 1.0
Date: 2026-05-28

## 1. Executive Summary

Sajha Kharcha is a mobile-first social finance module for eSewa that helps users manage shared spending with people they know. It lets users connect with friends, family, and colleagues, create expense groups, split bills, view transparent balances, settle dues through eSewa P2P payments, and send gift cards with money.

The current selected idea, Digital Dhukuti, is strong because it is culturally native to Nepal. The refined product keeps Digital Dhukuti as a flagship differentiator, but expands the core product around the full Challenge 10 requirement set: social connections, group expenses, balance transparency, settlement, and gifting.

For the hackathon, the recommended build is a responsive React web app with a Node.js Express backend, PostgreSQL database, local eSewa payment simulation, and optional OCR/ML services. The core prototype should prove the required Challenge 10 loop first: connect, create group, add expense, split, view balance, settle, and send a gift. Digital Dhukuti should be shown as a polished differentiator through a seeded or lightweight interactive flow only after the core loop is stable.

## 2. Product Name

Recommended app name: Sajha Kharcha

Why this name works:

- It directly signals shared expenses in a Nepali cultural context.
- It covers all use cases: friends splitting food, colleagues running a fund, families sending gifts, and groups managing recurring contributions.
- It is broader than Digital Dhukuti, so the product does not feel limited to rotating savings pools.
- It can be positioned as an eSewa-native social settlement layer.

Feature naming:

- Sajha Kharcha Groups: group expense management
- Sajha Kharcha Settle: one-tap settlement and debt simplification
- Sajha Kharcha Gifts: gift cards and group gifting
- Digital Dhukuti: rotating contribution ledger inside Sajha Kharcha
- Festival Mode: Dashain, Tihar, trek, bhoj, picnic, and apartment templates

## 3. Source Requirement Review

### 3.1 Challenge 10 Requirements Coverage

| Challenge requirement | Sajha Kharcha product response | MVP priority |
| --- | --- | --- |
| User connection mechanisms for financial interactions | Users connect by eSewa ID or phone number in MVP; QR invitation is a P1 enhancement. | P0 |
| Connection request approval and decline | Incoming requests support approve, decline, block, and report. | P0 |
| Connection removal | Users can remove a connection. Historical records remain visible; removal blocks new direct gifts and new group invitations, while existing shared-group participation continues until group membership is separately inactivated. | P0 |
| Connected users can create and participate in groups | Groups can only include accepted connections. Group roles include admin, member, and treasurer. | P0 |
| Record shared expenses | Users can add manual expenses with payer, amount, category, receipt, date, note, and members. | P0 |
| Split expenses among connected users | MVP supports equal and exact amount splits; percentage, shares, and item-level splits are P1. | P0 |
| Display who owes whom and how much | Group dashboard shows net balances, per-expense shares, and simplified settlement suggestions. | P0 |
| Track outstanding settlements | Outstanding dues are shown by group and across all groups. Settlement status can be pending, paid, failed, failed_review, expired, or cancelled. | P0 |
| Settlement reminders and payment prompts | In-app nudges show due reminders at configurable intervals. | P1 |
| Send gift cards with a monetary amount | Connected users can send themed money envelopes; group gift pools are P1. | P0 |
| Improve transparency in shared financial coordination | Every P0 expense, split, gift, and settlement has an activity log and timestamp. Seeded Dhukuti demo contributions can appear in activity; interactive Dhukuti contribution activity is P1. | P0 |
| Increase peer-to-peer transactions | Settlements and gifts trigger eSewa P2P payment intents in MVP; Dhukuti contribution payments are shown through seeded demo data or P1 interactive flow. | P0 |

### 3.2 Submission Guideline Coverage

| Submission requirement | Response |
| --- | --- |
| Team name | Cache Flow |
| Challenge | Challenge 10 |
| Problem understanding | PRD and deck should clearly explain current reliance on messaging apps, manual calculation, forgotten dues, and social discomfort around asking for money. |
| Proposed solution | Sajha Kharcha: social connections, groups, expense splitting, balance tracking, settlement, gifts, and Digital Dhukuti. |
| In-scope and out-of-scope | Defined in this PRD and should be added to the final deck. |
| User journey or flow | Dashain Khasi split journey is recommended for the demo story. |
| Technology stack | React.js, Node.js/Express, PostgreSQL, optional Python/scikit-learn, GitHub, local payment simulation. |
| Architecture diagram | Included as a logical architecture in this PRD; should be converted into the final deck visual. |
| Wireframes or UI/UX | Recommended screens are listed in section 12. |
| Source repository | GitHub repo with README, setup instructions, seeded demo data, and tech stack justification. |
| Demo video | 3 to 5 minute walkthrough using the Dashain group story. |
| File naming | CacheFlow_Challenge10_Submission |

### 3.3 Evaluation Criteria Alignment

| Criteria | Weight | How Sajha Kharcha should score |
| --- | ---: | --- |
| Problem Understanding | 10% | Shows Nepal-specific shared expense behavior, festival spending, trekking, office bhoj, apartment expenses, and Dhukuti coordination. |
| Innovation and Creativity | 20% | Digital Dhukuti, Festival Mode, group gifting, receipt-assisted split, and culturally native templates. |
| Technical Implementation | 25% | Demonstrable API, relational data model, balance engine, settlement simulation, and clear service boundaries. |
| UX/UI | 20% | Mobile-first group flow, one-tap templates, transparent balances, clear owed/owing language, and low-friction settlement. |
| Scalability and Feasibility | 15% | Uses allowed stack, local simulation, simple algorithms, and a production-friendly architecture. |
| Demo and Presentation | 10% | Single story arc: connect, create Dashain group, add bill, split, settle, send gift, show Dhukuti. |

## 4. Refined Product Positioning

### 4.1 Current Idea Strengths

- Strong cultural insight through Dhukuti, Dashain, Tihar, bhoj, and trekking use cases.
- Goes beyond a Splitwise clone by connecting settlement to eSewa P2P payments.
- Has a compelling business case for eSewa: more P2P transactions, repeat engagement, and group network effects.
- Festival Mode gives the demo emotional recall and local relevance.

### 4.2 Refinements Needed

1. Make Sajha Kharcha the main product and Digital Dhukuti a flagship module.
   - Challenge 10 is primarily about group expenses, connections, balances, settlement, and gifts.
   - Digital Dhukuti is a differentiator, but it should not make the product feel like only a savings pool app.

2. Correct the debt simplification explanation.
   - The deck currently says minimum spanning tree.
   - The better technical explanation is net-balance settlement simplification using a min-cash-flow style greedy matching algorithm.

3. Reduce MVP scope for hackathon feasibility.
   - Build the responsive web app first.
   - Treat Flutter mobile, Redis, advanced OCR, and ML as stretch goals.
   - Use a mock eSewa payment adapter unless a real sandbox is provided.

4. Treat Dhukuti carefully.
   - For MVP, Digital Dhukuti should be a contribution schedule and transparent ledger, not a regulated deposit, investment, loan, or credit product.
   - Production use should require compliance review, KYC limits, AML checks, participant consent, and dispute handling.

5. Avoid unsupported statistics unless sourced.
   - Numbers like 85%, 60%, and 3x should either be backed by survey data or reframed as qualitative observations.

## 5. Product Goals

### 5.1 User Goals

- Create a trusted financial connection with another eSewa user.
- Build a group for a shared activity in under one minute.
- Add an expense and split it without manual calculation.
- See who owes whom without confusion.
- Settle dues through eSewa in one tap.
- Send gifts or pooled money during festivals and group occasions.
- Track recurring Dhukuti-style contributions transparently through a seeded MVP ledger or interactive P1 flow.

### 5.2 Business Goals

- Increase eSewa P2P transaction volume through MVP settlements and gifts, with Dhukuti contribution payments as a clear phase-2 expansion.
- Increase user engagement by turning one-off payments into group workflows.
- Reduce off-platform coordination currently happening on messaging apps.
- Create a roadmap-ready product module that could be piloted with students, office teams, families, and travel groups.

### 5.3 Hackathon Goals

- Deliver a working prototype that demonstrates the end-to-end group expense lifecycle.
- Show a clear architecture and data model.
- Include at least one culturally differentiated flow: Dashain gift pool or Digital Dhukuti.
- Demonstrate settlement simulation through an eSewa-style payment confirmation flow.
- Use seeded accepted connections for the demo so the 6-member group can be created without spending stage time approving every participant.
- Prepare a concise 3 to 5 minute demo video and final pitch deck.

## 6. Target Users and Personas

### 6.1 College Friend Group

Needs:

- Split picnic, lunch, movie, transport, or birthday expenses.
- Avoid awkward reminders.
- Quickly see who has paid.

Primary features:

- Groups, equal split, nudges, one-tap settlement, gift envelopes.

### 6.2 Trek Organizer

Needs:

- Manage transport, guide, porter, food, accommodation, and equipment expenses.
- Handle one treasurer paying large shared costs.
- Settle after the trip.

Primary features:

- Treasurer Mode, categories, expense timeline, simplified settlements.

### 6.3 Festival Family or Friend Circle

Needs:

- Pool money for Dashain, Tihar, birthday, wedding, or group gifts.
- Send themed gift card with a monetary amount.

Primary features:

- Festival Mode, group gift pool, gift card templates, eSewa transfer.

### 6.4 Dhukuti Coordinator

Needs:

- Track recurring contribution commitments.
- See who has paid and whose turn is next.
- Maintain a transparent history.

Primary features:

- Digital Dhukuti ledger, contribution schedule, payout rotation, reminders, activity log.

## 7. Scope

### 7.1 Hackathon MVP Scope

P0 core loop to build:

- Demo login with seeded users.
- Send, approve, decline, and remove connection requests.
- Create a group using accepted connections.
- Add manual group expenses with payer, participants, category, and note.
- Split expenses using equal and exact-amount modes.
- Show group balance dashboard using expense and settlement ledger entries.
- Generate simplified settlement suggestions.
- Simulate eSewa P2P settlement with idempotent payment confirmation.
- Send a themed gift card with a monetary amount to an active connection.
- Show an activity timeline for connections, expenses, settlements, and gifts.
- Show a seeded Digital Dhukuti detail screen with contribution schedule and payout recipient.

P0 demo guardrails:

- Keep block and report as lightweight connection-safety actions that write events and immediately restrict new invitations/gifts; do not build a full moderation back office during the hackathon.
- Keep payment reconciliation local and mock-provider based, but still require every payment-derived success, opened, refunded, or failed_review domain state to reference a `payment_transactions` row.
- Keep locked-expense corrections narrow: locked expense edit/void attempts return a conflict response and point the user to an admin-only zero-sum adjustment flow.
- Keep settlement expiry/reuse deterministic and testable, but avoid production webhook retry infrastructure, notification workers, and manual-review dashboards in the hackathon build.

P1 features if time allows:

- Percentage and shares-based split modes.
- Interactive Digital Dhukuti creation, participation acceptance, and contribution payment simulation.
- Full block/report moderation workflow with review queue.
- Production-grade payment webhook retry history and manual-review dashboard.
- Receipt OCR for printed English bills using Tesseract or a controlled sample receipt parser.
- Item-level split for manual or OCR-parsed items.
- Smart item assignment suggestions based on prior group split history.
- Settlement reminders and due-state badges.
- Group expense PDF statement export.
- QR-based connection invite.

P2 stretch features:

- Flutter mobile app.
- Redis cache.
- Push notifications.
- Advanced OCR with cloud fallback.
- Admin dashboard.
- Multi-group batch settlement.
- Full demo video polish and analytics dashboard.

### 7.2 Out of Scope

- Real money custody by the prototype.
- Direct bank debit.
- Credit scoring, lending, investment, or interest-bearing products.
- Public Dhukuti marketplaces.
- Nepali language OCR.
- Handwritten receipt scanning.
- Multi-currency support.
- Offline-first sync.
- Real-time collaborative editing.
- Third-party integrations outside eSewa.
- Production KYC/AML workflow implementation.
- Trust scoring dashboard.

## 8. User Journeys

### 8.1 Connection Journey

1. User opens Sajha Kharcha.
2. User searches by eSewa ID or phone number.
3. User sends a connection request.
4. Recipient sees incoming request with requester name and mutual group context where available.
5. Recipient approves or declines.
6. Once approved, both users can create groups, split expenses, send gifts, and join Dhukuti pools.
7. Either user can remove the connection later.

Acceptance criteria:

- A user cannot add a non-connected member to a private expense group.
- A removed connection cannot be invited to new groups.
- Existing historical expenses remain visible for audit purposes.
- Removing a connection does not erase unpaid balances in shared groups.
- Removing a connection blocks new direct gifts and new group invitations, but does not automatically remove either user from existing shared groups.
- Existing groups use group membership as the permission boundary: active group members can appear in new group expenses; inactive or removed group members cannot.
- Blocking a user downgrades shared group interaction with that user to settlement-only for the blocker until unblocked.
- A group admin or the affected user can mark a removed connection as inactive inside a group; inactive members are excluded from new expenses by default but remain visible on historical expenses.
- Removed group members keep read-only access to historical expenses, settlements, and statements for groups they previously joined. They cannot see new expenses created after removal unless they are explicitly included again.

### 8.2 Dashain Khasi Split Journey

1. User selects Festival Mode.
2. User chooses Dashain Khasi Split.
3. App creates a themed group using seeded accepted connections for the live demo.
4. User adds an expense for khasi, masala, transport, and cooking.
5. User chooses split mode: equal for the core demo, or item-level if P1 is finished.
6. App updates group balances.
7. Members see who owes whom.
8. User taps Settle via eSewa.
9. Mock eSewa payment confirmation marks the settlement as paid.
10. Activity timeline records the expense and payment.

Acceptance criteria:

- Flow can be completed during a live demo in under 90 seconds.
- The balance dashboard updates immediately after settlement.

### 8.3 Group Gift Journey

1. User selects Sajha Kharcha Gifts.
2. User chooses a festival or occasion template.
3. User selects recipient from connections.
4. User enters gift amount and message.
5. User pays through eSewa P2P simulation.
6. Recipient sees a themed gift envelope and payment record.

Acceptance criteria:

- Gifts can only be sent to accepted connections.
- Gift is logged separately from expense settlements.

### 8.4 Digital Dhukuti Journey

MVP demo journey:

1. User opens a seeded Digital Dhukuti pool.
2. App shows contribution amount, frequency, payout order, current cycle, and member statuses.
3. User views contribution history and current payout recipient.
4. App highlights whether the cycle is on track or at-risk.

P1 interactive journey:

1. Organizer creates a Dhukuti pool.
2. Organizer sets contribution amount, frequency, start date, payout order, and member list.
3. Members accept participation.
4. App generates contribution schedule and cycles.
5. Members contribute through eSewa payment simulation.
6. App marks contribution status as paid, due, late, or missed.
7. At payout turn, app shows the recipient, expected payout amount, and payout status.
8. All actions are recorded in the ledger.

Acceptance criteria:

- Prototype clearly shows that Digital Dhukuti is a transparent ledger and payment scheduler.
- Prototype does not claim to provide credit, interest, investment return, or guaranteed payouts.

## 9. Functional Requirements

### 9.1 Accounts and Demo Login

FR-001: The app shall provide seeded demo users for hackathon presentation.

- Priority: P0
- Acceptance: User can switch between demo accounts without password complexity.

FR-002: The app shall store user profile fields required for social interaction.

- Priority: P0
- Fields: display name, phone, eSewa ID, avatar, district, created date.

### 9.2 Connections

FR-003: Users shall be able to send a connection request by phone or eSewa ID.

- Priority: P0
- Acceptance: Recipient receives a pending request.
- Edge cases: users cannot connect to themselves; duplicate and reverse duplicate requests are blocked by a normalized user-pair constraint; blocked users cannot send new requests.

FR-004: Users shall be able to approve, decline, remove, block, and report connection requests.

- Priority: P0
- Acceptance: State changes are reflected for both users.
- State machine: pending -> approved, declined, or expired; approved -> removed; declined, expired, or removed -> pending when a new request is sent and neither user has an active block. The normalized connection row is reused for retries, and every retry writes a new `connection_events` row. Block and unblock actions are stored in `connection_blocks`; "blocked" is a derived display state, not a base connection status.

FR-005: Users shall be able to view active connections and request history.

- Priority: P0
- Acceptance: Connections list separates active, pending, removed, and blocked-derived users.
- Acceptance: Request history is stored as connection events so the normalized connection row can prevent duplicates without losing audit history.

FR-006: Users shall control who can send them requests.

- Priority: P1
- Options: everyone, contacts only, QR invite only.

### 9.3 Groups

FR-007: Users shall be able to create a group with a name, category, members, and optional template.

- Priority: P0
- Categories: festival, trek, bhoj, travel, event, household, apartment, custom.

FR-008: Groups shall support member roles.

- Priority: P0
- Roles: admin, member, treasurer.

FR-009: Group admins shall be able to add or remove connected members.

- Priority: P0
- Acceptance: Removed members retain historical ledger visibility for expenses where they participated.
- Edge cases: removing a connection does not automatically remove group membership; group removal or inactive status is a separate action. Removed group members are excluded from new expenses by default; they can still view and settle balances created before removal.

FR-010: Groups shall have an activity timeline.

- Priority: P0
- Events: member added, member removed, expense added, expense voided, split edited, settlement pending, settlement paid, settlement expired, gift sent, gift cancelled, gift refunded, and seeded Dhukuti contribution activity for demo data.
- P1 events: interactive Dhukuti contribution payment, Dhukuti payout payment, gift pool contribution, receipt OCR parse, and item assignment.

### 9.4 Expenses and Splits

FR-011: Users shall be able to add a manual expense.

- Priority: P0
- Fields: title, total amount, payer, date, category, participants, note, optional receipt image.

FR-012: Users shall be able to split expenses equally.

- Priority: P0
- Acceptance: Total shares equal total expense amount.

FR-013: Users shall be able to split expenses by exact amount.

- Priority: P0
- Acceptance: App rejects submission when exact shares do not match total.

FR-014: Users shall be able to split expenses by percentage.

- Priority: P1
- Acceptance: App rejects submission when percentages do not total 100%.

FR-015: Users shall be able to split expenses by shares.

- Priority: P1
- Example: one user has 2x share, another has 1x share.

FR-016: Users shall be able to split expenses by item.

- Priority: P1
- Acceptance: Items can be assigned to one or more members.
- Edge cases: item-level split must support tax, service charge, discounts, rounded totals, and items shared by multiple members.

FR-017: Users shall be able to edit or void an expense.

- Priority: P1
- P0 guardrail: draft or unlocked expenses can be voided by setting expense status and writing an activity log entry.
- P1 edit flow: unsettled and unlocked expenses can be edited with activity log entries and balance recalculation.
- Edge cases: open balances are source-derived and exclude voided expenses, so voiding does not create reversal ledger events in MVP. Every paid group settlement locks all previously unlocked expenses created at or before the settlement payment timestamp. Locked expenses cannot be patched or voided; the API returns `409 Conflict` with an adjustment-required error code. Corrections to locked expenses must be recorded as zero-sum adjustment entries instead of hard deletion. This avoids ambiguous allocation because one simplified settlement may cover many expenses.

### 9.5 Receipt OCR and Smart Suggestions

FR-018: Users shall be able to upload or capture a printed English receipt.

- Priority: P1
- Acceptance: Prototype parses a controlled sample receipt into item names and amounts.

FR-019: The app shall allow users to assign receipt items to members.

- Priority: P1
- Acceptance: Confirmed item assignments create a group expense.

FR-020: The app shall suggest item assignments based on prior group behavior.

- Priority: P2
- Recommended approach: group-level frequency model using prior item-member assignments.
- Fallback: equal split or last-used member assignment.

### 9.6 Balances and Settlement

FR-021: The app shall calculate net group balances after each expense and paid settlement.

- Priority: P0
- Acceptance: Each member sees how much they owe or are owed.
- Acceptance: Paid settlements reduce open balances for payer and payee; pending, failed, failed_review, expired, and cancelled settlements do not.
- Acceptance: The dashboard separates open balance from pending payment state so a user does not see a second pay button for a debt already in pending settlement.

FR-022: The app shall generate simplified settlement suggestions.

- Priority: P0
- Algorithm: compute each member's net balance, then greedily match largest debtor to largest creditor until all balances are settled.
- Acceptance: Suggestions annotate or suppress payer/payee pairs that already have a pending settlement for the same group and amount.

FR-023: The app shall simulate one-tap eSewa P2P settlement.

- Priority: P0
- Acceptance: Settle action creates or reuses a pending settlement record first; payment confirmation links the payment transaction, marks that settlement paid, and updates balances.
- Edge cases: duplicate payment taps with the same idempotency key return the existing settlement result; partial settlement is allowed only if explicitly selected; overpayment is rejected in MVP.
- Idempotency: settlement payment idempotency keys are unique per payer, idempotency scope, and operation type.

FR-024: Users shall be able to settle all dues with one person in a group.

- Priority: P1
- Acceptance: App shows a single payable amount per counterparty.

FR-025: Users shall receive non-intrusive settlement nudges.

- Priority: P1
- Nudge intervals: 3 days, 7 days, 14 days.

### 9.7 Gifts

FR-026: Users shall be able to send a gift card with a monetary amount.

- Priority: P0
- Acceptance: Gift can only be sent to an active connection.
- Edge cases: cancelled, failed, or refunded gifts must not appear as successful transfers; private gift messages are visible only to sender and recipient.
- Idempotency: gift payment idempotency keys are unique per sender, idempotency scope, and operation type.

FR-027: Users shall be able to choose a gift template.

- Priority: P0
- Templates: Dashain, Tihar, birthday, wedding, thank you, custom.

FR-028: Users shall be able to create a group gift pool.

- Priority: P1
- Acceptance: Multiple contributors can add money toward one recipient.
- Edge cases: gift pool contributions must show contributor, amount, payment status, and refund/cancel state.

### 9.8 Digital Dhukuti

FR-029: Users shall be able to view a Digital Dhukuti pool and ledger.

- Priority: P0
- Acceptance: Seeded demo pool shows contribution amount, frequency, members, payout order, cycle status, contribution statuses, and current payout recipient.

FR-030: Users shall be able to create a Digital Dhukuti pool.

- Priority: P1
- Fields: name, contribution amount, frequency, start date, members, payout order.

FR-031: Members shall accept or decline Dhukuti participation.

- Priority: P1
- Acceptance: No member is added as active until they accept.

FR-032: The app shall generate contribution schedules and cycles.

- Priority: P1
- Acceptance: Schedule shows due date, contributor, amount, status, cycle number, and payout recipient.

FR-033: Members shall be able to mark or simulate a contribution payment.

- Priority: P1
- Acceptance: Payment updates the ledger and activity timeline.
- Edge cases: duplicate contribution payment attempts are idempotent by actor user, idempotency scope, operation type, and idempotency key; failed payments do not mark the contribution paid.

FR-034: The app shall show monthly payout recipient, expected payout, and payout status.

- Priority: P0
- Acceptance: Payout screen is read-only for MVP unless settlement simulation is enabled.
- Edge cases: if any contribution is missed before payout, the cycle is marked at-risk and payout is not shown as guaranteed.

FR-035: Members shall be able to request emergency exit.

- Priority: P2
- Acceptance: Organizer approval workflow is visible but may be simulated.

### 9.9 Statements and Reporting

FR-036: Users shall be able to export group statements.

- Priority: P2
- Format: PDF or CSV.

FR-037: Users shall be able to view personal activity across all groups.

- Priority: P1
- Acceptance: Dashboard summarizes owed, owed to user, pending gifts, and Dhukuti dues.

## 10. Non-Functional Requirements

### 10.1 Performance

- Balance recalculation should complete in under 200 ms for MVP groups with up to 50 expenses and 20 members.
- Settlement suggestion generation should complete in under 200 ms for MVP group sizes.
- Main dashboard should load in under 2 seconds on a local demo machine.

### 10.2 Reliability

- Payment simulation endpoints must be idempotent.
- Expense creation must be transactional: expense, shares, balance event, and activity log should succeed or fail together.
- Failed payment simulation should not mark settlement as paid.
- Pending payment records should expire or refresh rather than remain actionable forever.
- Domain payment records reference `payment_transactions`; provider callback state is not duplicated as separate provider/reference fields on settlement, gift, or Dhukuti tables.
- A payment-like domain record may have a null `payment_transaction_id` only before a provider intent is created. Any payment-derived success, opened, refunded, or failed_review domain state must reference a `payment_transactions` row.
- Payment status changes should preserve audit timestamps and transition history for callback debugging.

### 10.3 Privacy

- A user can only see groups where they are a current or historical member.
- A removed group member still counts as a historical member for read-only access to expenses, settlements, statements, and settlement-only actions created before their removal timestamp.
- A user can only invite active connections to private groups.
- Connection removal stops new direct gifts and group invitations between the two users but does not delete past records or automatically change existing group membership.
- Blocked users can still complete settlement-only actions for existing balances, with no gift, invite, or new expense permissions involving the blocker.
- Gift messages are visible only to sender and recipient unless the gift is part of a group pool.

### 10.4 Security

- Validate all split amounts server-side.
- Use role-based authorization for group actions.
- Do not trust client-calculated balances as final.
- Store payment simulation references and settlement IDs.
- Require idempotency keys for settlement, gift, and Dhukuti payment simulation endpoints.
- Scope idempotency uniqueness by actor user, idempotency scope, operation type, and idempotency key.
- Enforce payment provider reference uniqueness across payment-like records; a repeated provider reference for a different operation is routed to failed_review/manual review.
- Enforce domain/payment consistency: records cannot enter payment-derived success, opened, refunded, or failed_review states without a linked payment transaction.
- Enforce normalized unique user-pair constraints for connections to prevent duplicate or reverse duplicate requests.
- Avoid logging sensitive phone numbers or payment metadata in plaintext logs.
- Use rate limits for connection requests and payment prompts in production.

### 10.5 Accessibility and UX

- Use clear owed/owing labels with color and text, not color alone.
- Provide confirmation before sending payment, voiding expense, or removing a member.
- Keep the main flows usable on mobile widths.
- Avoid shame-based debt reminders; use neutral language.

## 11. Balance and Settlement Logic

### 11.1 Money Precision and Rounding

All money values must be stored as integer minor units, such as paisa, even when the UI displays NPR.

Rules:

- The API never stores floating-point money values.
- Equal, percentage, and shares-based splits calculate in minor units.
- Any rounding remainder is assigned deterministically using largest fractional remainder, then user ID as a stable tie-breaker.
- Expense split validation uses `total_minor`, the final payable amount after bill-level tax, service charge, tip, discount, and rounding adjustment.
- Exact-amount splits must sum to `total_minor` exactly.
- Percentage splits must sum to 100%; after conversion to money, any residual minor unit is assigned by the same deterministic remainder rule.
- The UI should show a small "rounding adjusted" note only when a visible NPR amount changes because of rounding.

### 11.2 Expense Balance Calculation

For each expense:

1. Add the full paid amount as credit to the payer.
2. Add each participant's share as debit to that participant.
3. Net balance = paid amount - owed share for each member.

Example:

- Sita pays NPR 6,000 for 6 people.
- Equal share is NPR 1,000.
- Sita net = +5,000.
- Each other member net = -1,000.

Open group balance must include paid settlements:

```text
open_balance[user] =
  active_expense_amounts_paid_by_user
  - active_expense_shares_owed_by_user
  + settlement_amounts_paid_by_user
  - settlement_amounts_received_by_user
  + adjustment_credits_for_user
  - adjustment_debits_for_user
```

This means a member who pays their settlement moves toward zero, the member who receives the settlement also moves toward zero, and correction entries can change balances without rewriting historical expenses or payments.

### 11.3 Ledger Events

The app should maintain an auditable group balance ledger or calculate an equivalent ledger view from source tables.

Required ledger events:

- Expense payer credit: payer receives a positive balance event.
- Expense share debit: each participant receives a negative balance event.
- Paid settlement payer credit: payer receives a positive balance event.
- Paid settlement payee debit: payee receives a negative balance event.
- Adjustment event: used when a settled expense must be corrected without rewriting payment history.

Rules:

- Pending, failed, failed_review, expired, or cancelled settlements must not affect open balances.
- Paid settlements must be idempotent by actor user, idempotency scope, operation type, and idempotency key before payment completion, then reconciled against `payment_transactions.payment_reference` after confirmation.
- Payment provider callbacks are first recorded in `payment_transactions`; duplicate provider references return the existing transaction, and provider references attached to a different operation are marked failed_review.
- Source expense and settlement records remain the system of record; ledger rows can be regenerated if needed.
- MVP balances are source-derived from active expenses, paid settlements, and zero-sum adjustments. `group_balance_events` is a read/audit projection and must not be used as an independent second source of truth.
- In `group_balance_events`, `source_id` maps to the exact source row that creates one balance movement: `expenses.id` for payer credit projections, `expense_shares.id` for share debit projections, `settlements.id` for paid settlement projections, and `adjustment_entries.id` for adjustment projections. It must not point to `adjustments.id`, because one adjustment can contain multiple credit/debit rows.
- Hard deletion of financial records is not allowed after they affect a balance; use adjustment entries, including reversal-type adjustments, instead.
- On every paid settlement, the server sets `locked_at` on all unlocked active expenses in that group where `created_at <= settlement.paid_at`, then updates `groups.latest_settlement_lock_at` to that settlement timestamp. Later corrections to locked expenses must be adjustment entries. Expenses created after that settlement remain editable until a later paid settlement locks them.
- Zero-sum is required for group balances: sum of all member open balances must equal zero after active expenses, paid settlements, and adjustments are applied.

### 11.4 Settlement Simplification

Use net-balance simplification, not minimum spanning tree.

Algorithm:

1. Compute net balance for every member.
2. Put positive balances into creditors.
3. Put negative balances into debtors.
4. Match the largest debtor with the largest creditor.
5. Create a settlement for the minimum of debtor amount and creditor amount.
6. Update both balances.
7. Repeat until all balances are zero.

Benefits:

- Reduces noisy many-to-many debts into fewer payment suggestions.
- Easy to explain to judges.
- Fast enough for hackathon and production group sizes.

## 12. UX and Screen Requirements

### 12.1 Recommended Navigation

Primary tabs:

- Home
- Groups
- Connections
- Gifts
- Dhukuti
- Activity

### 12.2 MVP Screens

1. Home dashboard
   - Total you owe
   - Total owed to you
   - Pending settlements
   - Upcoming Dhukuti dues from seeded read-only ledger in MVP
   - Recent activity

2. Connections
   - Search by eSewa ID or phone
   - Incoming requests
   - Active connections
   - Remove/block actions

3. Groups list
   - Group cards with category, member count, your balance, and due status

4. Group detail
   - Balance summary
   - Add expense button
   - Settlement suggestions
   - Activity timeline

5. Add expense
   - Amount, payer, category, participants
   - Split mode selector
   - Optional item split for P1

6. Settlement confirmation
   - Payee
   - Amount
   - Group
   - eSewa-style confirmation button

7. Gift card
   - Recipient
   - Template
   - Amount
   - Message

8. Digital Dhukuti detail
   - Pool amount
   - Members
   - Contribution schedule
   - Current payout recipient
   - Payment status

9. Festival Mode template picker
   - Dashain Khasi Split
   - Tihar Gift Pool (P1, disabled or read-only in MVP)
   - New Year Trek
   - Office Bhoj
   - College Picnic
   - Apartment Monthly

## 13. System Architecture

### 13.1 Recommended Hackathon Architecture

Client:

- React.js with Vite or Next.js
- Tailwind CSS
- TanStack Query for API state
- React Router or Next.js routing

API:

- Node.js with Express.js
- TypeScript preferred
- Prisma or Drizzle ORM
- REST API

Database:

- PostgreSQL
- Seeded demo data
- Docker Compose if time permits

Optional services:

- Python FastAPI service for ML item suggestions
- Tesseract OCR or controlled sample parser for receipt demo
- Redis only if real-time cache is needed

External adapter:

- eSewa Payment API sandbox if available
- Otherwise local mock payment adapter with realistic request and response shape

Version control:

- GitHub repository
- README with setup, stack, architecture, demo credentials, and known limitations

### 13.2 Logical Architecture

```text
React Web App
  |
  | REST API
  v
Node.js Express API
  |-- Auth and Demo Users
  |-- Connections
  |-- Groups and Expenses
  |-- Balance Engine
  |-- Ledger and Adjustments
  |-- Settlement Adapter
  |-- Gifts
  |-- Digital Dhukuti
  |
  | SQL
  v
PostgreSQL

Optional:
Node.js API -> Python ML/OCR Service
Node.js API -> Redis Cache
Node.js API -> eSewa Payment Sandbox or Mock Adapter
```

## 14. Data Model

### 14.1 Core Tables

All money amounts below should be stored as integer minor units, such as paisa, and displayed as NPR in the UI.

users:

- id
- display_name
- phone
- esewa_id
- avatar_url
- district
- created_at
- constraints: unique(phone); unique(esewa_id)

connections:

- id
- requester_id
- recipient_id
- user_low_id
- user_high_id
- status: pending, approved, declined, expired, removed
- expires_at
- created_at
- updated_at
- constraints: requester_id != recipient_id; unique(user_low_id, user_high_id)
- retry rule: declined, expired, or removed pairs reuse the same normalized row by changing status back to pending and writing a new `connection_events` row.

connection_blocks:

- id
- connection_id
- blocker_id
- blocked_user_id
- status: active, lifted
- created_at
- lifted_at
- constraints: unique(connection_id, blocker_id, blocked_user_id, status) for active blocks

connection_events:

- id
- connection_id
- actor_id
- event_type: requested, approved, declined, expired, removed, blocked, unblocked, reported
- previous_status
- next_status
- metadata_json
- created_at

connection_reports:

- id
- connection_id
- reporter_id
- reported_user_id
- reason_code
- details nullable
- status: open, reviewed, dismissed, resolved
- created_at
- reviewed_at nullable
- Hackathon behavior: `POST /connections/:id/report` creates an `open` report and a `connection_events` row with event_type `reported`; the moderation review queue is P1.

groups:

- id
- name
- category
- template
- created_by
- latest_settlement_lock_at nullable
- created_at

group_members:

- id
- group_id
- user_id
- role: admin, member, treasurer
- status: active, removed
- joined_at
- removed_at nullable
- constraints: unique active membership per `(group_id, user_id)` where status is active

group_member_periods:

- id
- group_id
- user_id
- role
- joined_at
- left_at nullable
- end_reason nullable
- created_by
- constraints: no overlapping active periods for the same `(group_id, user_id)`; a new period starts only after the previous period has `left_at` set

group_member_events:

- id
- group_id
- user_id
- actor_id
- event_type: joined, removed, readded, role_changed, left
- metadata_json
- created_at

expenses:

- id
- group_id
- title
- subtotal_minor
- total_minor
- payer_id
- category
- split_mode
- status: draft, active, voided
- expense_date
- note
- receipt_url
- bill_tax_minor
- bill_service_charge_minor
- bill_discount_minor
- bill_tip_minor
- bill_rounding_adjustment_minor
- locked_at nullable
- voided_at nullable
- voided_by nullable
- void_reason nullable
- created_by
- created_at

Expense amount semantics:

- `subtotal_minor` is the pre-tax/pre-tip item or manual subtotal.
- `total_minor = subtotal_minor + bill_tax_minor + bill_service_charge_minor + bill_tip_minor + bill_rounding_adjustment_minor - bill_discount_minor`.
- Expense shares must sum to `total_minor`.

expense_shares:

- id
- expense_id
- user_id
- amount_minor
- percentage
- share_units
- source_type: manual, item
- source_id

expense_items:

- id
- expense_id
- label
- quantity
- unit_amount_minor
- total_amount_minor
- tax_minor
- service_charge_minor
- discount_minor
- ocr_confidence
- sort_order

Item charge semantics for P1:

- Item-level tax, service charge, and discount fields are OCR/source-detail fields.
- When item-level charges are present, they roll up into the expense-level bill fields; they are not added again on top of `bill_tax_minor`, `bill_service_charge_minor`, or `bill_discount_minor`.
- The canonical split target remains `expenses.total_minor`.

expense_item_assignments:

- id
- expense_item_id
- user_id
- assigned_amount_minor
- split_units

group_balance_events:

- id
- group_id
- user_id
- source_type: expense_payer, expense_share, settlement, adjustment
- source_id
- amount_minor
- direction: credit, debit
- created_at
- constraints: unique(source_type, source_id, user_id, direction)
- source_id mapping: `expenses.id` for expense payer projections, `expense_shares.id` for expense share projections, `settlements.id` for settlement projections, and `adjustment_entries.id` for adjustment projections.

payment_transactions:

- id
- payment_provider
- payment_reference
- operation_type
- entity_type
- entity_id
- actor_id
- amount_minor
- status: pending, paid, failed, failed_review, expired, cancelled, refunded
- raw_payload_json
- created_at
- updated_at
- confirmed_at nullable
- failed_at nullable
- expired_at nullable
- cancelled_at nullable
- refunded_at nullable
- constraints: unique(payment_provider, payment_reference) when payment_reference is not null

payment_transaction_events:

- id
- payment_transaction_id
- previous_status nullable
- next_status
- event_type: intent_created, callback_received, confirmed, failed, expired, cancelled, refunded, mismatch_detected, manual_review_marked
- metadata_json
- created_at

Payment record rules:

- `payment_transactions` is the payment audit anchor for settlements, gifts, gift pool contributions, Dhukuti contributions, and Dhukuti payouts.
- Domain rows may be created before a provider intent and temporarily keep `payment_transaction_id` null while status is draft-like or pending without provider reference.
- Domain rows in `paid`, `sent`, `opened`, `refunded`, or `failed_review` payment-derived states must have `payment_transaction_id` populated.
- Domain rows in `failed`, `expired`, or `cancelled` must also have `payment_transaction_id` populated when that state came from a provider intent, callback, or provider reconciliation.
- Domain status is a product-facing projection; provider callback truth and raw metadata stay in `payment_transactions` and `payment_transaction_events`.

adjustments:

- id
- group_id
- reason
- adjustment_type: correction, reversal, refund, manual
- reverses_source_type nullable
- reverses_source_id nullable
- created_by
- created_at

adjustment_entries:

- id
- adjustment_id
- user_id
- amount_minor
- direction: credit, debit

Adjustment rules:

- P0 adjustments must be zero-sum: total credit amount must equal total debit amount.
- Non-zero-sum external refunds or platform-funded corrections are out of MVP scope and require manual review in production.
- Adjustment entries are the only source of adjustment balance changes; expense shares are not used for adjustments.

settlements:

- id
- group_id
- payer_id
- payee_id
- amount_minor
- status: pending, paid, failed, failed_review, expired, cancelled
- payment_transaction_id nullable until provider intent; required when status is paid or failed_review, and required for failed/expired/cancelled when provider-derived
- idempotency_key
- idempotency_scope
- operation_type
- failure_reason
- expires_at
- balance_snapshot_hash
- created_at
- paid_at
- constraints: unique(payer_id, idempotency_scope, operation_type, idempotency_key)
- constraints: unique pending settlement per `(group_id, payer_id, payee_id, amount_minor)` where status is pending; expired pending rows must be moved to status expired before a replacement is created

gift_cards:

- id
- sender_id
- recipient_id
- group_id nullable
- template
- amount_minor
- message
- status: pending, sent, opened, failed, failed_review, expired, cancelled, refunded
- payment_transaction_id nullable until provider intent; required when status is sent, opened, failed_review, or refunded, and required for failed/expired/cancelled when provider-derived
- idempotency_key
- idempotency_scope
- operation_type
- opened_at
- created_at
- refunded_at
- constraints: unique(sender_id, idempotency_scope, operation_type, idempotency_key)

gift_pools:

- id
- group_id
- created_by
- recipient_id
- title
- template
- target_amount_minor
- message
- status: open, completed, cancelled, refunded
- created_at

gift_pool_contributions:

- id
- gift_pool_id
- contributor_id
- amount_minor
- status: pending, paid, failed, failed_review, expired, cancelled, refunded
- payment_transaction_id nullable until provider intent; required when status is paid, failed_review, or refunded, and required for failed/expired/cancelled when provider-derived
- idempotency_key
- idempotency_scope
- operation_type
- created_at
- paid_at
- constraints: unique(contributor_id, idempotency_scope, operation_type, idempotency_key)

dhukuti_pools:

- id
- group_id
- name
- contribution_amount_minor
- frequency
- start_date
- created_by
- status: draft, active, completed, cancelled
- created_at

dhukuti_members:

- id
- pool_id
- user_id
- payout_order
- status: invited, active, declined, exited

dhukuti_cycles:

- id
- pool_id
- cycle_number
- due_date
- payout_recipient_id
- expected_contribution_total_minor
- paid_contribution_total_minor
- status: upcoming, open, at_risk, ready_for_payout, paid_out, closed, cancelled

dhukuti_contributions:

- id
- pool_id
- cycle_id
- user_id
- cycle_number
- due_date
- amount_minor
- status: due, pending, paid, late, missed, failed, failed_review, expired, cancelled
- payment_transaction_id nullable until provider intent; required when status is paid or failed_review, and required for failed/expired/cancelled when provider-derived
- idempotency_key
- idempotency_scope
- operation_type
- paid_at
- constraints: unique(user_id, idempotency_scope, operation_type, idempotency_key)

dhukuti_payouts:

- id
- pool_id
- cycle_id
- recipient_id
- amount_minor
- status: pending, paid, failed, failed_review, expired, cancelled
- payment_transaction_id nullable until provider intent; required when status is paid or failed_review, and required for failed/expired/cancelled when provider-derived
- idempotency_key
- idempotency_scope
- operation_type
- failure_reason
- paid_at
- constraints: unique(recipient_id, idempotency_scope, operation_type, idempotency_key)

activity_logs:

- id
- actor_id nullable for system/provider events
- actor_type: user, system, provider
- group_id nullable
- event_type
- entity_type
- entity_id
- metadata_json
- created_at

notifications:

- id
- user_id
- type
- title
- body
- status: unread, read
- created_at

## 15. API Requirements

All payment-like mutation endpoints must accept an idempotency key and return the existing result when the same key is retried.

### 15.1 Connections

- POST /connections/requests
- GET /connections/requests
- PATCH /connections/requests/:id
- GET /connections
- POST /connections/:id/remove
- POST /connections/:id/block
- POST /connections/:id/unblock
- POST /connections/:id/report

Connection API rules:

- If a pair already has a declined, expired, or removed connection row, `POST /connections/requests` reuses that row by setting it to pending and writing a new request event.
- `POST /connections/:id/report` creates a `connection_reports` row, writes a `connection_events` entry, and does not expose a P0 moderation queue.

### 15.2 Groups and Expenses

- POST /groups
- GET /groups
- GET /groups/:id
- POST /groups/:id/members
- POST /groups/:id/members/:userId/remove
- POST /groups/:id/expenses
- GET /groups/:id/expenses
- PATCH /expenses/:id
- POST /expenses/:id/void
- GET /groups/:id/balances
- GET /groups/:id/ledger
- POST /groups/:id/adjustments

Expense API rules:

- `PATCH /expenses/:id` returns `409 Conflict` when the expense is locked, voided, or no longer editable because a paid settlement has locked its period.
- `POST /expenses/:id/void` returns `409 Conflict` for locked expenses and includes an `adjustment_required` error code.
- `POST /groups/:id/adjustments` is admin-only in MVP and must validate that credit totals equal debit totals before writing entries.

### 15.3 Settlement

- GET /groups/:id/settlement-suggestions
- POST /settlements
- POST /settlements/:id/pay
- GET /users/me/settlements

Settlement API rules:

- `POST /settlements` creates or reuses a pending settlement for a valid payer/payee/group/amount and returns that pending settlement.
- `POST /settlements/:id/pay` creates or links a payment transaction, records payment events, and moves the settlement to paid only after successful mock/provider confirmation.
- If a matching pending settlement already exists with a different idempotency key, the API returns the existing pending settlement instead of creating a duplicate.

### 15.4 Gifts

- POST /gifts
- GET /users/me/gifts
- POST /gifts/:id/cancel
- POST /gifts/:id/refund
- POST /gift-pools
- POST /gift-pools/:id/contributions
- POST /gift-pools/:id/cancel
- POST /gift-pools/:id/refund

### 15.5 Digital Dhukuti

P0 read-only seeded endpoints:

- GET /dhukuti/pools
- GET /dhukuti/pools/:id
- GET /dhukuti/pools/:id/ledger

P1 mutating endpoints:

- POST /dhukuti/pools
- POST /dhukuti/pools/:id/invitations/:invitationId/respond
- POST /dhukuti/pools/:id/contributions/:contributionId/pay
- POST /dhukuti/pools/:id/payouts/:payoutId/pay

## 16. Recommended Tech Stack

### 16.1 Hackathon MVP Stack

Frontend:

- React.js
- Tailwind CSS
- TanStack Query
- React Router

Backend:

- Node.js
- Express.js
- TypeScript
- Prisma ORM

Database:

- PostgreSQL

AI/ML or smart assistance:

- Python FastAPI with scikit-learn for optional item suggestion
- Rule-based fallback in Node.js if time is limited

OCR:

- Tesseract-based local OCR or controlled sample parser for demo
- Cloud OCR can be mentioned as production option, not MVP dependency

Payment:

- eSewa Payment API sandbox if available
- Local mock adapter if sandbox is unavailable

Deployment:

- Local simulation acceptable for hackathon
- Optional: Vercel/Render/Firebase/Supabase for hosted demo

Version control:

- GitHub

### 16.2 Why This Stack Fits the Guidelines

- React.js is explicitly allowed for frontend.
- Node.js and Express.js are explicitly allowed for backend.
- Python is allowed for AI/ML and can be used only where needed.
- PostgreSQL is an allowed optional database and fits relational financial records.
- GitHub is mandatory and should be used from day one.
- Local simulation is allowed when deployment or external API access is constrained.

## 17. Metrics

### 17.1 Product Metrics

- Time to create a group.
- Time to add and split an expense.
- Percentage of expenses settled within 7 days.
- Number of P2P settlement intents generated.
- Number of gift payments sent.
- Number of Dhukuti contributions recorded in seeded MVP ledger or P1 interactive flow.
- Reduction in settlement transactions after simplification.

### 17.2 Demo Success Metrics

- Complete core demo flow in under 3 minutes.
- Create one group, add one expense, show balance, settle payment, send gift, and show Dhukuti ledger without switching tools.
- No manual database changes during demo.
- Seed data supports fallback if OCR or payment sandbox fails.

## 18. Edge Case Rules

### 18.1 Membership Edge Cases

- A member who joins a group after previous expenses is excluded from historical expenses by default.
- A removed group member remains visible on historical expenses and settlement records.
- A removed or blocked connection can complete settlement-only flows for existing balances.
- If all admins leave a group, the earliest active member becomes admin in MVP.
- A user leaving a group with an unpaid balance remains a historical member until the balance is settled or adjusted.
- If an admin leaves while group invites are pending, the earliest remaining active admin inherits those pending invite controls; if no admin remains, the earliest active member becomes admin first.
- A member removed and later re-added is tracked through `group_member_periods`; they are excluded from expenses created during removed intervals unless manually added through an adjustment.
- Expired pending connection requests cannot be approved; the requester must send a new request.
- Blocking a user who is the only admin of a shared group does not remove their admin role; the blocker sees only settlement-safe actions involving that admin until another admin is assigned.

### 18.2 Expense Edge Cases

- The payer can be excluded from the split, for example when one person pays for others but does not participate.
- MVP supports one payer per expense. Multiple payers for one bill should be entered as separate expenses or deferred to P2.
- Receipt-level tax, service charge, discounts, tips, and rounding adjustments are allocated proportionally across assigned participants unless manually overridden.
- Rounded totals are handled using the deterministic rounding rule in section 11.1.
- Negative expenses are not allowed; refunds or corrections use adjustment entries.
- Zero-value expenses are rejected in MVP.
- If an expense is created at the exact same timestamp as a settlement callback, the server uses transaction commit order; settlement locking applies to expenses committed before the paid settlement transaction.
- If an unlocked expense is voided while a pending settlement exists for the same payer/payee/group and no provider payment has been confirmed, the pending settlement is expired and settlement suggestions must be regenerated.
- If an expense is voided after a partial settlement is pending but before provider confirmation, the pending settlement is expired unless the remaining open balance still exactly supports it.
- If a user tries to patch or void a locked expense, the server rejects the request with `409 Conflict` and does not alter the expense or balance projection.

### 18.3 Settlement Edge Cases

- Partial settlement is allowed only when the payer explicitly edits the payment amount below the suggested amount.
- Overpayment is rejected in MVP.
- Failed, failed_review, expired, cancelled, and pending payments do not affect open balances.
- Duplicate payment taps must return the same result when the idempotency key matches.
- If a paid settlement must be reversed, create an adjustment settlement or refund record instead of deleting the original payment.
- Self-settlement is rejected.
- Payer and payee must both be current or historical members of the group.
- If a payment callback arrives after a user cancels locally, the server reconciles by final payment status and records an activity log entry.
- If a pending settlement already exists for the same payer, payee, group, and amount, a new settle action reuses or replaces that pending settlement instead of creating a duplicate.
- If the provider callback amount differs from the requested settlement amount, the settlement is marked failed_review and does not affect open balances until manually reconciled.
- Pending settlements expire at `expires_at`; expired settlements no longer suppress settlement suggestions.
- If group balance changes while a settlement is pending, the dashboard shows both the pending payment and the updated open balance. A later paid callback applies only if the paid amount is still valid against the current payer/payee balance; otherwise it moves to failed_review.
- If a known `payment_reference` arrives with a different operation type or entity than the original transaction, the existing payment transaction wins and the new callback is marked failed_review.
- A settlement cannot move to paid or failed_review unless it links to the payment transaction that produced that state.
- Every settlement payment state transition writes a `payment_transaction_events` row before the domain settlement state is updated.
- Adjustment entries that would over-correct and flip a member from debtor to creditor, or creditor to debtor, require explicit confirmation and an activity log reason.
- Adjustment credits and debits must balance in P0. Any non-zero-sum correction is rejected or sent to manual review.

### 18.4 Gift Edge Cases

- Gifts can only be sent to active connections.
- Zero-value gifts are rejected.
- A gift sent to the wrong recipient can be cancelled only while pending.
- Sent gifts require a refund flow; they cannot be silently deleted.
- Gift `expired` and `failed_review` states are displayed from the domain row, not hidden inside provider metadata.
- If a gift refund succeeds after the recipient has opened the card, the card remains visible with refunded status and no success celebration.
- Private gift messages must not appear in group activity unless the gift belongs to a group gift pool.
- If a gift payment succeeds after the recipient connection was removed mid-flow, the gift remains delivered if the payment was already confirmed; no new gift actions are allowed afterward unless the connection is restored.
- A gift cannot move to sent, opened, refunded, or failed_review unless it links to the payment transaction that produced or reconciled that state.

### 18.5 Digital Dhukuti Edge Cases

- A Dhukuti member is not active until they accept participation.
- If a member misses a contribution before a payout, the cycle is marked at-risk and payout is not displayed as guaranteed.
- Failed payout attempts remain in the payout ledger with failure reason.
- Emergency exit is P2 and must not rewrite completed contribution or payout history.

## 19. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Scope is too large for hackathon | Incomplete prototype | Prioritize P0 web app. Treat Flutter, Redis, OCR, ML, item-level split, and interactive Dhukuti as stretch. |
| Payment API sandbox unavailable | Demo blocker | Build a mock eSewa payment adapter with realistic confirmation states. |
| OCR fails during live demo | Demo embarrassment | Use controlled sample receipt and manual item entry fallback. |
| Dhukuti raises compliance questions | Judge concern | Position MVP as transparent ledger and payment scheduler, not deposit, lending, or investment product. |
| Unsupported statistics in deck | Credibility issue | Replace with survey-backed or qualitative claims. |
| Balance math bug | Product trust issue | Unit test split validation, net balance, and settlement simplification. |
| Privacy concern around social connections | Adoption risk | Require accepted connections, add block/remove, and restrict group invites. |
| Pending payment causes duplicate payment attempt | Product trust issue | Separate open balance from pending payment state and suppress duplicate pay actions for matching pending settlements. |

## 20. Testing Plan

P0 unit tests:

- Equal split calculation.
- Exact amount validation.
- Deterministic money rounding and residual allocation.
- Net balance calculation.
- Voided expenses excluded from open balance calculation.
- Paid settlement offset in open balance calculation.
- Adjustment credit/debit offset in open balance calculation.
- Expense share projection source IDs use `expense_shares.id`.
- Adjustment projection source IDs use `adjustment_entries.id`.
- Settlement simplification.
- Duplicate payment idempotency.
- Duplicate pending settlement prevention with a new idempotency key.
- Payment reference duplicate callback handling.
- Provider callback amount mismatch rejection.
- Provider callback operation/entity mismatch handling.
- Payment-derived success, opened, refunded, failed, expired, cancelled, and failed_review domain states require linked payment transaction when provider-derived.
- Payment transaction status changes create transition events.
- Zero-sum adjustment validation.
- Connection permissions.
- Duplicate and reverse duplicate connection request prevention.
- Declined, expired, or removed connection retry reuses the normalized pair row and writes a new event.
- Expired connection request rejection.
- Connection report creates report row and event row.
- User lookup by phone and eSewa ID uniqueness.
- Active group membership uniqueness and non-overlapping member periods.
- Gift recipient permission.
- Gift expired and failed_review states map to visible domain statuses.
- System/provider activity events use nullable actor or system actor type.
- Zero-value expense and gift rejection.
- Self-settlement rejection.
- Adjustment over-correction confirmation.

P1/P2 unit tests:

- Percentage validation.
- Share-based split calculation.
- Dhukuti schedule generation.
- Dhukuti at-risk cycle when a contribution is missed.

P0 integration tests:

- Connection request lifecycle.
- Group creation with connected members.
- Expense creation and balance update.
- Voided expense removal from balances.
- Settlement payment simulation.
- Pending settlement creation before payment confirmation.
- Existing pending settlement reuse.
- Existing pending settlement reuse when the retry uses a new idempotency key.
- Pending settlement expiry after balance changes.
- Gift card sending.
- Gift completion after recipient connection removal.
- Expense adjustment after settlement.
- Settlement lock after each paid group settlement.
- Locked expense patch and void requests return `409 Conflict`.
- Late payment callback after local cancellation.
- Expense voiding expires matching pending settlement.
- Expense void after partial pending settlement.

P1/P2 integration tests:

- Dhukuti contribution payment.

Manual QA:

- Mobile-width UI checks.
- Demo flow rehearsal.
- Seed data reset.
- Payment failure scenario.
- Removed connection behavior.
- Blocked user with historical unpaid balance.
- Member joining after historical expenses.
- User leaving a group with unpaid balance.
- Payer or payee not in group.
- Member removed and later re-added.
- Admin leaves while invites are pending.
- User blocks the only admin of a shared group.
- Gift refund after recipient has opened the card.

## 21. Hackathon Delivery Plan

### Day 0 or Setup

- Create GitHub repository.
- Set up React app and Express API.
- Define database schema and seed data.
- Assign roles within Cache Flow.

### Day 1

- Build connections API and UI.
- Implement normalized connection pairs and derived block state.
- Build groups API and UI.
- Implement manual expense creation.
- Implement expense void state for unlocked expenses.
- Implement equal and exact-amount split validation.

### Day 2

- Implement balance engine.
- Implement settlement suggestions.
- Implement `payment_transactions` and local mock eSewa payment events.
- Implement deterministic pending settlement reuse, expiry, idempotency, and mock reconciliation.
- Implement settlement locks, locked-expense conflict responses, and the minimal admin-only zero-sum adjustment flow.
- Build gifts module.
- Build activity timeline.
- Add seeded Digital Dhukuti ledger screen.

### Day 3

- Polish mobile UI.
- Add Festival Mode templates.
- Add P1 features only after the core loop is demo-stable: percentage/share split, interactive Dhukuti, item split, or OCR.
- Write README.
- Record demo video.
- Finalize pitch deck with updated app name and corrected technical claims.

## 22. Demo Script

Recommended 3-minute story:

1. Hook:
   - "Most shared expenses in Nepal still end in screenshots, chat reminders, and awkward follow-ups."

2. Connection:
   - Search and connect with one friend by eSewa ID.
   - Use seeded accepted connections for the remaining demo members.

3. Festival Mode:
   - Choose Dashain Khasi Split.
   - Create a 6-member group.

4. Expense:
   - Add a catering or khasi expense.
   - Split equally for the core demo; switch to item split only if P1 is finished.

5. Balance:
   - Show who owes whom.
   - Explain simplified settlement.

6. Settlement:
   - Tap Pay via eSewa.
   - Mock confirmation updates that member's balance; the full group reaches zero only if all suggested settlements are completed.

7. Gift:
   - Send a Tihar or Dashain gift card with money.

8. Digital Dhukuti:
   - Show a seeded monthly contribution pool, cycle status, payout recipient, and transparent ledger.

9. Close:
   - "Sajha Kharcha brings shared expenses, gifts, and Digital Dhukuti into eSewa, where the money already moves."

## 23. Deck Update Recommendations

Update the existing deck as follows:

- Replace placeholder team name with Cache Flow.
- Rename the product from Digital Dhukuti to Sajha Kharcha, with Digital Dhukuti as the flagship module.
- Replace "minimum spanning tree algorithm" with "net-balance settlement simplification algorithm."
- Mark Flutter, Redis, advanced OCR, ML, item-level split, and interactive Dhukuti creation as stretch or phase 2 unless the team is confident.
- Show Digital Dhukuti as a seeded ledger in the core demo, then mention interactive creation as the next build milestone.
- Phrase business impact as "MVP creates eSewa transactions through settlements and gifts; Dhukuti contribution payments expand the transaction loop in phase 2."
- Reframe unsupported statistics unless there is source data.
- Add a compliance-safe note for Digital Dhukuti:
  - "Hackathon MVP is a transparent contribution ledger and payment scheduler. Production release would require eSewa compliance review."
- Add one slide or section mapping the product directly to Challenge 10 requirements.
- Keep the demo story focused on one continuous Dashain group flow.

## 24. Open Questions

- Will eSewa provide a payment API sandbox for hackathon teams?
- Are eSewa IDs available in test data, or should the prototype use phone numbers only?
- Are gift card templates allowed to use eSewa branding assets?
- Is a legal/compliance mentor available to review the Digital Dhukuti framing?
- Should the final prototype be hosted, or is local demo acceptable?
- Does the judging panel prefer mobile app demos, or is responsive web sufficient?

## 25. Final Recommendation

Cache Flow should build Sajha Kharcha as a focused, working social expense prototype, not a broad concept deck. The winning path is:

1. Nail the required Challenge 10 flows: connect, group, split, balance, settle, gift.
2. Use Digital Dhukuti as the memorable Nepal-specific differentiator.
3. Keep the MVP technically honest and demo-ready.
4. Show how every settlement and gift becomes an eSewa transaction in MVP, with Dhukuti contributions as the next expansion.
5. Pitch Sajha Kharcha as a product eSewa could realistically pilot after the hackathon.
