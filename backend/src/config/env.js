import 'dotenv/config';

function csv(value) {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function configured(value) {
  return Boolean(value && !value.startsWith('replace-with') && value !== 'YOUR-PASSWORD');
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 3000),
  host: process.env.HOST ?? '127.0.0.1',
  allowedOrigins: csv(process.env.ALLOWED_ORIGINS),
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseSecretKey: process.env.SUPABASE_SECRET_KEY,
  supabasePublishableKey: process.env.SUPABASE_PUBLISHABLE_KEY,
  supabaseJwtSecret: process.env.SUPABASE_JWT_SECRET,
  redisUrl: process.env.REDIS_URL ?? 'redis://127.0.0.1:6379',
  authAccessTokenSecret:
    process.env.AUTH_ACCESS_TOKEN_SECRET ??
    (process.env.NODE_ENV === 'production' ? undefined : 'dev-only-change-before-production'),
  authAccessTokenTtlMinutes: Number(process.env.AUTH_ACCESS_TOKEN_TTL_MINUTES ?? 15),
  authRefreshTokenTtlDays: Number(process.env.AUTH_REFRESH_TOKEN_TTL_DAYS ?? 30),
  realtimeTokenTtlMinutes: Number(process.env.REALTIME_TOKEN_TTL_MINUTES ?? 10),
  otpTtlMinutes: Number(process.env.OTP_TTL_MINUTES ?? 5),
  otpResendCooldownSeconds: Number(process.env.OTP_RESEND_COOLDOWN_SECONDS ?? 60),
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID,
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN,
  twilioFromPhoneNumber: process.env.TWILIO_FROM_PHONE_NUMBER,
  twilioMessagingServiceSid: process.env.TWILIO_MESSAGING_SERVICE_SID,
};

env.hasSupabaseSecret = configured(env.supabaseSecretKey);
env.hasSupabaseConfig = Boolean(env.supabaseUrl && env.hasSupabaseSecret);
env.hasSupabaseRealtimeConfig = Boolean(
  env.supabaseUrl &&
    configured(env.supabasePublishableKey) &&
    configured(env.supabaseJwtSecret),
);
env.isProduction = env.nodeEnv === 'production';
env.hasAuthAccessTokenSecret = Boolean(env.authAccessTokenSecret);
env.hasTwilioSmsConfig = Boolean(
  configured(env.twilioAccountSid) &&
    configured(env.twilioAuthToken) &&
    (configured(env.twilioFromPhoneNumber) || configured(env.twilioMessagingServiceSid)),
);

if (env.isProduction && !env.hasAuthAccessTokenSecret) {
  throw new Error('Missing AUTH_ACCESS_TOKEN_SECRET.');
}
