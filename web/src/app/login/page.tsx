import { signIn, signInWithPassword, signOut } from './actions';
import { supabaseConfig } from '@/lib/supabase/config';

export default async function Login({
  searchParams,
}: {
  searchParams: Promise<{ message?: string }>;
}) {
  const { message } = await searchParams;
  const ready = !!supabaseConfig();
  const messages: Record<string, string> = {
    restricted: 'This account does not have superadmin access.',
    failed: 'Sign-in could not be completed. Check credentials and Auth setup.',
    invalid: 'Incorrect username or password.',
    configuration: 'The sign-in callback is not configured yet.',
  };
  return (
    <main className="login">
      <div className="login-brand brand">
        <span className="brand-mark" aria-hidden />
        <span>
          <strong>TrimMatrix</strong>
          <em>Admin</em>
        </span>
      </div>
      <p className="eyebrow">Administration</p>
      <h1>Sign in to manage salons</h1>
      <p className="muted">
        Review registrations, approve businesses, and keep employee contracts in
        one place.
      </p>
      <section className="panel">
        <div className="panel-head">
          <h2>Superadmin sign-in</h2>
        </div>
        {!ready ? (
          <p className="notice">
            The portal is ready for setup. Connect Supabase to enable sign-in.
          </p>
        ) : (
          <>
            {message && messages[message] && (
              <p
                role="alert"
                className={
                  message === 'invalid' || message === 'failed' || message === 'restricted'
                    ? 'notice notice-error'
                    : 'notice'
                }
              >
                {messages[message]}
              </p>
            )}
            <form action={signInWithPassword}>
              <label className="field">
                <span>Username</span>
                <input
                  name="username"
                  type="text"
                  autoComplete="username"
                  required
                  placeholder="Username"
                />
              </label>
              <label className="field">
                <span>Password</span>
                <input
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  required
                  placeholder="Password"
                />
              </label>
              <button type="submit" style={{ width: '100%' }}>
                Sign in
              </button>
            </form>
            <div className="login-divider">or</div>
            <form action={signIn}>
              <button type="submit" className="btn-secondary">
                Continue with Google
              </button>
            </form>
            {message === 'restricted' && (
              <form action={signOut}>
                <p style={{ marginTop: 14 }}>
                  <button type="submit" className="btn-ghost">
                    Sign out of this account
                  </button>
                </p>
              </form>
            )}
          </>
        )}
      </section>
      <p className="muted login-foot">
        Access is limited to approved administrators.
      </p>
    </main>
  );
}
