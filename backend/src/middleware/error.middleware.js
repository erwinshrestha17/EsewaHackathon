import { ApiError } from '../utils/ApiError.js';

export function errorMiddleware(error, _req, res, _next) {
  if (error instanceof ApiError) {
    res.status(error.status).json({
      error: error.message,
      details: error.details,
    });
    return;
  }

  console.error(error);
  res.status(500).json({ error: 'Unexpected server error.' });
}
