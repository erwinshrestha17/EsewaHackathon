import { createClient } from '@supabase/supabase-js';

import { env } from './env.js';

let adminClient;
let authClient;

export function supabaseAdmin() {
  if (adminClient) {
    return adminClient;
  }
  if (!env.supabaseUrl || !env.hasSupabaseSecret) {
    throw new Error(
      'Missing SUPABASE_URL or a real SUPABASE_SECRET_KEY. Copy backend/.env.example to backend/.env and fill the server-only sb_secret value.',
    );
  }
  adminClient = createClient(env.supabaseUrl, env.supabaseSecretKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  return adminClient;
}

export function supabaseAuthClient() {
  if (authClient) {
    return authClient;
  }
  const key = env.supabasePublishableKey || env.supabaseSecretKey;
  if (!env.supabaseUrl || !key) {
    throw new Error('Missing Supabase URL or API key for auth verification.');
  }
  authClient = createClient(env.supabaseUrl, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  return authClient;
}
