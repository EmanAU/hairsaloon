import { AdminShell } from './admin-shell';

/** Thin wrapper for pages that only need the shell chrome. */
export function Header({
  name,
  activeView = 'businesses',
  children,
}: {
  name: string;
  activeView?: string;
  children?: React.ReactNode;
}) {
  return (
    <AdminShell name={name} activeView={activeView}>
      {children}
    </AdminShell>
  );
}
