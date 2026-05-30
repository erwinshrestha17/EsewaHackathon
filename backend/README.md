# Sajha Kharcha API

Node.js/Express API for Sajha Kharcha. It uses Supabase PostgreSQL as the system of record, Redis for OTP/session cache and invalidation, and Twilio for signup OTP delivery.

## Setup

1. Copy the environment template:

   ```bash
   cp backend/.env.example backend/.env
   ```

2. Fill server-side Supabase values in `backend/.env`:

   - `SUPABASE_URL`
   - `SUPABASE_SECRET_KEY` as a server-only `sb_secret_...` key
   - `SUPABASE_PUBLISHABLE_KEY` for token verification

3. Fill auth/session infrastructure values:

   - `REDIS_URL`
   - `AUTH_ACCESS_TOKEN_SECRET`
   - `TWILIO_ACCOUNT_SID`
   - `TWILIO_AUTH_TOKEN`
   - `TWILIO_FROM_PHONE_NUMBER` or `TWILIO_MESSAGING_SERVICE_SID`

4. Apply database structure:

   ```bash
   supabase link --project-ref vrhajoztnsadxbumfdzy
   supabase db push
   ```

   If the Supabase CLI is unavailable, run these files in the Supabase SQL editor in order:

   - `supabase/migrations/20260530081500_create_community_savings.sql`
   - `supabase/migrations/20260530120000_create_full_app_backend.sql`
   - `supabase/migrations/20260530085341_add_mpin_auth_sessions.sql`
   - `supabase/migrations/20260530150000_production_auth.sql`

   `supabase/seed.sql` is intentionally empty and does not recreate demo users.

5. Start Redis locally, then run the API:

   ```bash
   redis-server
   cd backend
   npm install
   npm run dev
   ```

6. Run Flutter against the local backend on macOS:

   ```bash
   flutter run -d macos --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
   flutter run -d chrome --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
   ```

## Authentication

The app signup UX is Nepal mobile number + Twilio OTP + M-PIN. Login is verified Nepal mobile number + M-PIN.

Backend auth endpoints:

- `POST /api/auth/signup/otp`
- `POST /api/auth/signup`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/auth/logout-all`

M-PIN values are never stored directly. They are stored in `app_user_credentials.mpin_hash` as PBKDF2-SHA256 hashes. Login returns a short-lived JWT access token and an opaque refresh token. API clients send the access token as:

```http
Authorization: Bearer eyJ...
```

Refresh tokens are stored only as hashes in `app_sessions` and rotated by `POST /api/auth/refresh`. Redis caches active session state and OTP challenges; Postgres remains the source of truth.

Run Flutter against the backend auth/API layer with:

```bash
flutter run -d macos --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
flutter run -d chrome --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
```

On Linux web, make sure `BACKEND_API_BASE_URL` is reachable from the browser,
not just from the terminal. For VMs, containers, or another device on the LAN,
bind the backend to the network and use the host IP:

```bash
HOST=0.0.0.0 npm run dev
flutter run -d chrome --dart-define=BACKEND_API_BASE_URL=http://192.168.1.25:3000
```

## Main Endpoints

- `GET /health`
- `GET /api/me`
- `PATCH /api/me`
- `POST /api/auth/signup/otp`
- `POST /api/auth/signup`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/auth/logout-all`
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
