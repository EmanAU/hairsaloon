import Link from 'next/link';
import { signOut } from '@/app/login/actions';

export function Header({ name }: { name: string }) {
  return <header><Link href="/"><strong>TrimMatrix</strong></Link><span>Superadmin · {name}</span>
    <form action={signOut}><button>Sign out</button></form></header>;
}
