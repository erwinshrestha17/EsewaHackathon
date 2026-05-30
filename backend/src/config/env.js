import 'dotenv/config';

function csv(value) {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 3000),
  host: process.env.HOST ?? '127.0.0.1',
  allowedOrigins: csv(process.env.ALLOWED_ORIGINS),
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseSecretKey: process.env.SUPABASE_SECRET_KEY,
  supabasePublishableKey: process.env.SUPABASE_PUBLISHABLE_KEY,
  redisUrl: process.env.REDIS_URL ?? 'redis://127.0.0.1:6379',
  authAccessTokenSecret:
    process.env.AUTH_ACCESS_TOKEN_SECRET ??
    (process.env.NODE_ENV === 'production' ? undefined : 'dev-only-change-before-production'),
  authAccessTokenTtlMinutes: Number(process.env.AUTH_ACCESS_TOKEN_TTL_MINUTES ?? 15),
  authRefreshTokenTtlDays: Number(process.env.AUTH_REFRESH_TOKEN_TTL_DAYS ?? 30),
  otpTtlMinutes: Number(process.env.OTP_TTL_MINUTES ?? 5),
  otpResendCooldownSeconds: Number(process.env.OTP_RESEND_COOLDOWN_SECONDS ?? 60),
  awsRegion: process.env.AWS_REGION,
  awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID,
  awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  awsSessionToken: process.env.AWS_SESSION_TOKEN,
  awsSnsSmsSenderId: process.env.AWS_SNS_SMS_SENDER_ID,
};

env.hasSupabaseSecret = Boolean(
  env.supabaseSecretKey &&
    !env.supabaseSecretKey.startsWith('replace-with') &&
    env.supabaseSecretKey !== 'YOUR-PASSWORD',
);
env.hasSupabaseConfig = Boolean(env.supabaseUrl && env.hasSupabaseSecret);
env.isProduction = env.nodeEnv === 'production';
env.hasAuthAccessTokenSecret = Boolean(env.authAccessTokenSecret);
env.hasAwsSnsConfig = Boolean(
  env.awsRegion && env.awsAccessKeyId && env.awsSecretAccessKey,
);

if (env.isProduction && !env.hasAuthAccessTokenSecret) {
  throw new Error('Missing AUTH_ACCESS_TOKEN_SECRET.');
}
