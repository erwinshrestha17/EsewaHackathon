import 'dotenv/config';

function csv(value) {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export const env = {
  port: Number(process.env.PORT ?? 3000),
  host: process.env.HOST ?? '127.0.0.1',
  allowedOrigins: csv(process.env.ALLOWED_ORIGINS),
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseSecretKey: process.env.SUPABASE_SECRET_KEY,
  supabasePublishableKey: process.env.SUPABASE_PUBLISHABLE_KEY,
  allowDemoAuth: process.env.ALLOW_DEMO_AUTH !== 'false',
  demoUserId: process.env.DEMO_USER_ID ?? 'u-sita',
};

env.hasSupabaseSecret = Boolean(
  env.supabaseSecretKey &&
    !env.supabaseSecretKey.startsWith('replace-with') &&
    env.supabaseSecretKey !== 'YOUR-PASSWORD',
);
env.hasSupabaseConfig = Boolean(env.supabaseUrl && env.hasSupabaseSecret);
