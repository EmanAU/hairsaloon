'use server';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

const DEFAULT_USERNAME = 'yesiamrana';
const DEFAULT_PASSWORD = '12345678';
const DEFAULT_EMAIL = 'yesiamrana@trimmatrix.admin';

function adminCredentials() {
  return {
    username: (process.env.ADMIN_USERNAME ?? DEFAULT_USERNAME).trim(),
    password: process.env.ADMIN_PASSWORD ?? DEFAULT_PASSWORD,
    email: (process.env.ADMIN_EMAIL ?? DEFAULT_EMAIL).trim().toLowerCase(),
  };
}

export async function signInWithPassword(formData: FormData) {
  const username = String(formData.get('username') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const admin = adminCredentials();

  if (
    !username ||
    !password ||
    username.toLowerCase() !== admin.username.toLowerCase() ||
    password !== admin.password
  ) {
    redirect('/login?message=invalid');
  }

  const client = await createClient();
  const { error } = await client.auth.signInWithPassword({
    email: admin.email,
    password: admin.password,
  });
  if (error) redirect('/login?message=failed');
  redirect('/');
}

export async function signIn() {
  const site = process.env.SITE_URL;
  if (!site) redirect('/login?message=configuration');
  const client = await createClient();
  const { data, error } = await client.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: new URL('/auth/callback', site).toString() },
  });
  if (error || !data.url) redirect('/login?message=failed');
  redirect(data.url);
}

export async function signOut() {
  const client = await createClient();
  await client.auth.signOut();
  redirect('/login');
}
