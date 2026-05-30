import { db, assertDb } from '../common/db.js';

export async function getSettings(userId) {
  const { data, error } = await db()
    .from('user_settings')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();
  assertDb(error);
  return data ?? {};
}

export async function updateSettings(userId, body) {
  const payload = {
    user_id: userId,
    theme_mode: body.themeMode,
    language: body.language,
    push_preview_enabled: body.pushPreviewEnabled,
    confirm_before_payment: body.confirmBeforePayment,
    biometric_enabled: body.biometricEnabled,
    notification_preferences: body.notificationPreferences,
  };
  for (const key of Object.keys(payload)) {
    if (payload[key] === undefined) delete payload[key];
  }
  const { data, error } = await db()
    .from('user_settings')
    .upsert(payload, { onConflict: 'user_id' })
    .select()
    .single();
  assertDb(error);
  return data;
}
