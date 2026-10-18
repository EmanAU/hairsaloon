import { signIn, signOut } from './actions';
import { supabaseConfig } from '@/lib/supabase/config';

export default async function Login({ searchParams }: {
  searchParams: Promise<{ message?: string }>;
}) {
  const { message } = await searchParams;
  const ready = !!supabaseConfig();
  const messages: Record<string, string> = {
    restricted: 'This account does not have superadmin access.',
    failed: 'Sign-in could not be completed. Please try again.',
    configuration: 'The sign-in callback is not configured yet.',
  };
  return <main className="login"><div className="eyebrow">TrimMatrix / Administration</div>
    <h1>Your salons.<br />One clear view.</h1>
    <p className="muted">Review registrations, manage businesses and keep track of employee contracts.</p>
    <section className="panel"><h2>Superadmin sign-in</h2>
      {!ready ? <p className="notice">The portal is ready for setup. Connect Supabase to enable sign-in.</p> : <>
        {message && messages[message] && <p role="alert" className="notice">{messages[message]}</p>}
        <form action={signIn}><button>Continue with Google</button></form>
        {message === 'restricted' && <form action={signOut}><p><button>Sign out of this account</button></p></form>}
      </>}
    </section><p className="muted">Access is limited to approved administrators.</p>
  </main>;
}
