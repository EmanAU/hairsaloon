import 'server-only';
import { redirect } from 'next/navigation';
import { createClient } from './supabase/server';

export async function requireAdmin() {
  const client = await createClient();
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) redirect('/login');
  const { data: account, error: accountError } = await client.from('users')
    .select('id, display_name, role').eq('id', user.id).single();
  if (accountError || account?.role !== 'superadmin') redirect('/login?message=restricted');
  return { client, account };
}
