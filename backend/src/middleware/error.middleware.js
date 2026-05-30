import { ApiError } from '../utils/ApiError.js';
import { env } from '../config/env.js';

export function errorMiddleware(error, _req, res, _next) {
  if (error instanceof ApiError) {
    const body = { error: error.message };
    if (!env.isProduction && error.details && !(error.details instanceof Error)) {
      body.details = error.details;
    }
    res.status(error.status).json(body);
    return;
  }

  console.error(error);
  res.status(500).json({ error: 'Unexpected server error.' });
}
