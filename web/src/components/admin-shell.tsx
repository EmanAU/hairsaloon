import Link from 'next/link';
import { signOut } from '@/app/login/actions';

const NAV = [
  { view: 'businesses', label: 'Businesses' },
  { view: 'users', label: 'Users' },
  { view: 'contracts', label: 'Contracts' },
  { view: 'reminders', label: 'Ending soon' },
  { view: 'reviews', label: 'Reviews' },
] as const;

export function AdminShell({
  name,
  activeView = 'businesses',
  children,
}: {
  name: string;
  activeView?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="sidebar-top">
          <Link href="/?view=businesses" className="brand">
            <span className="brand-mark" aria-hidden />
            <span>
              <strong>TrimMatrix</strong>
              <em>Admin</em>
            </span>
          </Link>
          <p className="sidebar-user">
            Signed in as
            <span>{name}</span>
          </p>
          <nav className="side-nav" aria-label="Admin">
            {NAV.map((item) => (
              <Link
                key={item.view}
                href={`/?view=${item.view}`}
                aria-current={activeView === item.view ? 'page' : undefined}
              >
                {item.label}
              </Link>
            ))}
          </nav>
        </div>
        <form action={signOut} className="sidebar-foot">
          <button type="submit" className="btn-ghost">
            Sign out
          </button>
        </form>
      </aside>
      <div className="shell-main">{children}</div>
    </div>
  );
}
