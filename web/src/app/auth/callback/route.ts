import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get('code');
  if (code) {
    const client = await createClient();
    const { error } = await client.auth.exchangeCodeForSession(code);
    if (!error) {
      const { data: { user } } = await client.auth.getUser();
      if (user) {
        const { data: account, error: lookupError } = await client.from('users').select('id').eq('id', user.id).maybeSingle();
        if (lookupError) return NextResponse.redirect(new URL('/login?message=failed', request.url));
        if (!account) {
          const { error: createError } = await client.from('users').insert({
            id: user.id, display_name: String(user.user_metadata.full_name || 'User').slice(0, 120),
          });
          // A concurrent first login may already have created the same identity.
          if (createError && createError.code !== '23505') {
            return NextResponse.redirect(new URL('/login?message=failed', request.url));
          }
        }
        return NextResponse.redirect(new URL('/', request.url));
      }
    }
  }
  return NextResponse.redirect(new URL('/login?message=failed', request.url));
}
