import { BrandLogo } from '@/components/brand-logo';
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
    <main className="login-split">
      <section className="login-hero" aria-label="TrimMatrix Admin">
        <div className="login-hero-inner">
          <div className="login-brand brand">
            <BrandLogo size={48} />
            <span>
              <strong>TrimMatrix</strong>
              <em>Admin</em>
            </span>
          </div>
          <p className="eyebrow">Administration</p>
          <h1>
            Your salons.
            <br />
            One clear view.
          </h1>
          <p className="muted login-hero-copy">
            Review registrations, approve businesses, and keep employee
            contracts under control — from a single professional console.
          </p>
          <ul className="login-points">
            <li>Approve and manage salon businesses</li>
            <li>Monitor staff contracts and reminders</li>
            <li>Moderate customer reviews safely</li>
          </ul>
        </div>
      </section>

      <section className="login-panel" aria-label="Sign in">
        <div className="login-panel-card">
          <div className="panel-head">
            <h2>Sign in</h2>
            <p className="muted">Use your superadmin credentials to continue.</p>
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
                    message === 'invalid' ||
                    message === 'failed' ||
                    message === 'restricted'
                      ? 'notice notice-error'
                      : 'notice'
                  }
                >
                  {messages[message]}
                </p>
              )}
              <form action={signInWithPassword} className="login-form">
                <label className="field">
                  <span>Username</span>
                  <input
                    name="username"
                    type="text"
                    autoComplete="username"
                    required
                    placeholder="Enter username"
                  />
                </label>
                <label className="field">
                  <span>Password</span>
                  <input
                    name="password"
                    type="password"
                    autoComplete="current-password"
                    required
                    placeholder="Enter password"
                  />
                </label>
                <button type="submit" className="btn-block">
                  Sign in
                </button>
              </form>
              <div className="login-divider">or</div>
              <form action={signIn}>
                <button type="submit" className="btn-secondary btn-block">
                  Continue with Google
                </button>
              </form>
              {message === 'restricted' && (
                <form action={signOut}>
                  <p className="login-restricted">
                    <button type="submit" className="btn-ghost">
                      Sign out of this account
                    </button>
                  </p>
                </form>
              )}
            </>
          )}
          <p className="muted login-foot">
            Access is limited to approved administrators.
          </p>
        </div>
      </section>
    </main>
  );
}
