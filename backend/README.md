# Sajha Kharcha API

Node.js/Express API for the Flutter prototype. It uses Supabase PostgreSQL as the data store and keeps the current Flutter UI flow intact by preserving the legacy Community Savings Tracker endpoints.

## Setup

1. Copy the environment template:

   ```bash
   cp backend/.env.example backend/.env
   ```

2. Fill server-side Supabase values in `backend/.env`:

   - `SUPABASE_URL`
   - `SUPABASE_SECRET_KEY` as a server-only `sb_secret_...` key
   - `SUPABASE_PUBLISHABLE_KEY` for token verification

3. Apply database structure and seed data:

   ```bash
   supabase link --project-ref vrhajoztnsadxbumfdzy
   supabase db push
   supabase db query --linked --file supabase/seed.sql
   ```

   If the Supabase CLI is unavailable, run these files in the Supabase SQL editor in order:

   - `supabase/migrations/20260530081500_create_community_savings.sql`
   - `supabase/migrations/20260530120000_create_full_app_backend.sql`
   - `supabase/seed.sql`

4. Run the API:

   ```bash
   cd backend
   npm install
   npm run dev
   ```

5. Run Flutter against the local community savings API:

   ```bash
   flutter run --dart-define=COMMUNITY_SAVINGS_API_BASE_URL=http://127.0.0.1:3000/api/community-savings
   ```

## Authentication

The app login UX remains Nepal mobile number + M-PIN.

Backend login endpoints:

- `POST /api/auth/mpin/login`
- `POST /api/auth/mpin/register`
- `POST /api/auth/logout`

M-PIN values are never stored directly. They are stored in `app_user_credentials.mpin_hash` as PBKDF2-SHA256 hashes. Login returns a backend session token with the `sajha_` prefix; API clients should send it as:

```http
Authorization: Bearer sajha_...
```

The backend can also verify Supabase Auth JWTs, but the Flutter phone + M-PIN path uses backend sessions so the UI does not need to change.

For the seeded prototype:

- Phone: `9800000001`
- M-PIN: `1234`

`ALLOW_DEMO_AUTH=true` lets requests without a bearer token act as `DEMO_USER_ID` (`u-sita` by default). Keep `ALLOW_DEMO_AUTH=false` outside local-only testing.

Run Flutter against the backend auth/API layer with:

```bash
flutter run --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
```

## Main Endpoints

- `GET /health`
- `GET /api/me`
- `PATCH /api/me`
- `POST /api/auth/mpin/login`
- `POST /api/auth/mpin/register`
- `POST /api/auth/logout`
- `POST /api/groups`
- `GET /api/groups`
- `GET /api/groups/:groupId`
- `PATCH /api/groups/:groupId`
- `DELETE /api/groups/:groupId`
- `GET /api/groups/:groupId/members`
- `POST /api/groups/:groupId/members`
- `PATCH /api/groups/:groupId/members/:memberId`
- `DELETE /api/groups/:groupId/members/:memberId`
- `GET /api/connections`
- `GET /api/connections/search?q=maya`
- `POST /api/connections`
- `POST /api/connections/:connectionId/approve`
- `POST /api/connections/:connectionId/decline`
- `DELETE /api/connections/:connectionId`
- `GET /api/expenses/group/:groupId`
- `POST /api/expenses/group/:groupId`
- `GET /api/settlements`
- `POST /api/settlements/group/:groupId`
- `POST /api/settlements/group/:groupId/:settlementId/confirm`
- `GET /api/gifts`
- `POST /api/gifts`
- `POST /api/gifts/:giftId/open`
- `GET /api/gifts/pools/group/:groupId`
- `POST /api/gifts/pools/group/:groupId`
- `POST /api/gifts/pools/:giftPoolId/contributions`
- `GET /api/community-savings`
- `POST /api/community-savings`
- `GET /api/community-savings/:savingsGroupId/dashboard`
- `PATCH /api/community-savings/:savingsGroupId`
- `GET /api/community-savings/:savingsGroupId/contributions?month=YYYY-MM`
- `POST /api/community-savings/:savingsGroupId/contributions/submit`
- `POST /api/community-savings/contributions/:contributionId/confirm`
- `POST /api/community-savings/contributions/:contributionId/waive`
- `POST /api/community-savings/:savingsGroupId/expenses`
- `GET /api/community-savings/:savingsGroupId/history`
- `GET /api/community-savings/:savingsGroupId/balance`
- `GET /api/notifications`
- `PATCH /api/notifications/:notificationId/read`
- `PATCH /api/notifications/read-all`
- `GET /api/activity-logs`
- `GET /api/settings`
- `PATCH /api/settings`

Legacy Flutter-compatible paths remain available under `/api/community-savings/groups/...`.

## Tests

Syntax and unit tests:

```bash
cd backend
npm test
```

Remote integration tests require a real `SUPABASE_SECRET_KEY` in `backend/.env` and are opt-in because they write test records:

```bash
cd backend
RUN_REMOTE_API_TESTS=true npm test
```
