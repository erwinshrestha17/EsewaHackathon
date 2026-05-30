import cors from 'cors';
import express from 'express';
import helmet from 'helmet';

import { env } from './config/env.js';
import { errorMiddleware } from './middleware/error.middleware.js';
import { authenticateUser, optionalAuth } from './middleware/auth.middleware.js';
import { appBootstrapRouter } from './modules/appBootstrap/appBootstrap.routes.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { activityLogsRouter } from './modules/activityLogs/activityLogs.routes.js';
import { communitySavingsRouter } from './modules/communitySavings/communitySavings.routes.js';
import { connectionsRouter } from './modules/connections/connections.routes.js';
import { expensesRouter } from './modules/expenses/expenses.routes.js';
import { giftsRouter } from './modules/gifts/gifts.routes.js';
import { groupsRouter } from './modules/groups/groups.routes.js';
import { notificationsRouter } from './modules/notifications/notifications.routes.js';
import { settingsRouter } from './modules/settings/settings.routes.js';
import { settlementsRouter } from './modules/settlements/settlements.routes.js';

export const app = express();

app.disable('x-powered-by');
app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || env.allowedOrigins.length === 0 || env.allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Origin is not allowed by CORS.'));
    },
  }),
);
app.use(express.json({ limit: '1mb' }));

app.get('/health', optionalAuth, (req, res) => {
  res.json({
    ok: true,
    service: 'sajha-kharcha-api',
    supabaseConfigured: env.hasSupabaseConfig,
    user: req.userProfile?.id ?? null,
  });
});

app.use('/api', authRouter);
app.use('/api/app', authenticateUser, appBootstrapRouter);
app.use('/api/groups', authenticateUser, groupsRouter);
app.use('/api/connections', authenticateUser, connectionsRouter);
app.use('/api/expenses', authenticateUser, expensesRouter);
app.use('/api/settlements', authenticateUser, settlementsRouter);
app.use('/api/gifts', authenticateUser, giftsRouter);
app.use('/api/community-savings', authenticateUser, communitySavingsRouter);
app.use('/api/notifications', authenticateUser, notificationsRouter);
app.use('/api/activity-logs', authenticateUser, activityLogsRouter);
app.use('/api/settings', authenticateUser, settingsRouter);

app.use(errorMiddleware);
