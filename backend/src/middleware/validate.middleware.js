import { ApiError } from '../utils/ApiError.js';

export function requireFields(source, fields) {
  for (const field of fields) {
    const value = source[field];
    if (value === undefined || value === null || value === '') {
      throw new ApiError(400, `${field} is required.`);
    }
  }
}

export function requireBody(fields) {
  return (req, _res, next) => {
    try {
      requireFields(req.body ?? {}, fields);
      next();
    } catch (error) {
      next(error);
    }
  };
}

export function assertChoice(value, choices, field) {
  if (value !== undefined && value !== null && !choices.includes(value)) {
    throw new ApiError(400, `${field} must be one of: ${choices.join(', ')}.`);
  }
}

export function parseMoneyMinor(value, field) {
  const amount = Number(value);
  if (!Number.isInteger(amount) || amount <= 0) {
    throw new ApiError(400, `${field} must be an integer amount in paisa greater than 0.`);
  }
  return amount;
}
