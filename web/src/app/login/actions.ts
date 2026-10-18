'use server';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

export async function signIn() {
  const site = process.env.SITE_URL;
  if (!site) redirect('/login?message=configuration');
  const client = await createClient();
  const { data, error } = await client.auth.signInWithOAuth({
    provider: 'google', options: { redirectTo: new URL('/auth/callback', site).toString() },
  });
  if (error || !data.url) redirect('/login?message=failed');
  redirect(data.url);
}

export async function signOut() {
  const client = await createClient();
  await client.auth.signOut();
  redirect('/login');
}
