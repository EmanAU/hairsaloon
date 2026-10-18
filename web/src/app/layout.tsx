import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = { title: 'TrimMatrix Admin', description: 'Salon administration' };

export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
