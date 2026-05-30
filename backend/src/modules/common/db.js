import { supabaseAdmin } from '../../config/supabase.js';
import { ApiError } from '../../utils/ApiError.js';

export function db() {
  return supabaseAdmin();
}

export function assertDb(error) {
  if (error) {
    const status = error.code === 'PGRST116' ? 404 : 500;
    throw new ApiError(status, error.message, error);
  }
}

export async function single(query, notFoundMessage = 'Record not found.') {
  const { data, error } = await query.single();
  if (error?.code === 'PGRST116') {
    throw new ApiError(404, notFoundMessage);
  }
  assertDb(error);
  return data;
}

export async function maybeSingle(query) {
  const { data, error } = await query.maybeSingle();
  assertDb(error);
  return data;
}

export function normalizeId(value) {
  return value?.toString().trim();
}

export function isUuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value ?? '',
  );
}

export async function findByIdOrLegacy(table, id, legacyColumn = 'legacy_id') {
  const column = isUuid(id) ? 'id' : legacyColumn;
  return maybeSingle(db().from(table).select('*').eq(column, id));
}

export function pageRange(query, { limit = 50, offset = 0 } = {}) {
  const normalizedLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
  const normalizedOffset = Math.max(Number(offset) || 0, 0);
  return query.range(normalizedOffset, normalizedOffset + normalizedLimit - 1);
}
