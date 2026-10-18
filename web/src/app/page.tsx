import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/auth';
import { supabaseConfig } from '@/lib/supabase/config';
import { Header } from '@/components/header';
import { reviewBusiness, releaseContract, deleteReview } from './actions';
import { date, contractStatus } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function Home({ searchParams }: {
  searchParams: Promise<{ view?: string; page?: string; message?: string }>;
}) {
  if (!supabaseConfig()) redirect('/login');
  const { client, account } = await requireAdmin();
  const params = await searchParams;
  const view = ['businesses', 'users', 'contracts', 'reminders', 'reviews'].includes(params.view ?? '') ? params.view! : 'businesses';
  const page = Math.max(0, Math.min(100000, Number.parseInt(params.page ?? '0') || 0));
  const table = view === 'contracts' ? 'employee_contracts' : view === 'reminders' ? 'contract_reminders' : view;
  const { data, error, count } = await client.from(table).select('*', { count: 'exact' })
    .order(view === 'reminders' ? 'ends_at' : 'created_at', { ascending: view === 'reminders' })
    .range(page * 25, page * 25 + 24);
  if (error) throw new Error('Could not load administration data. Check the database setup and try again.');
  const rows = data ?? [];
  return <><Header name={account.display_name} /><main>
    <div className="eyebrow">Workspace overview</div><h1>Salon administration</h1>
    <p className="muted">Business approvals, people and contracts.</p>
    <nav>{['businesses', 'users', 'contracts', 'reminders', 'reviews'].map(item =>
      <Link key={item} href={`/?view=${item}`} aria-current={view === item ? 'page' : undefined}>
        {item === 'reminders' ? 'Ending in 7 days' : item[0].toUpperCase() + item.slice(1)}
      </Link>)}</nav>
    {params.message && <p className="notice" role="alert">The change could not be saved. Refresh the record and try again.</p>}
    <section className="panel"><div className="row spread"><h2>{view === 'reminders' ? 'Upcoming contract expiry' : view[0].toUpperCase() + view.slice(1)}</h2><span className="muted">{count ?? 0} records</span></div>
      {!rows.length ? <p className="empty">No records to show.</p> : <table>
        <thead><tr>{(view === 'businesses' ? ['Business', 'Location', 'Status', 'Action'] :
          view === 'users' ? ['Name', 'Role', 'Joined'] : view === 'reviews' ? ['Salon / barber', 'Customer', 'Review', 'Moderation'] : view === 'contracts' ? ['Employee', 'Type', 'Period', 'Status / release'] :
          ['Employee', 'Contract', 'Ends']).map(label => <th key={label}>{label}</th>)}</tr></thead>
        <tbody>{rows.map(row => <tr key={row.id}>
          {view === 'businesses' ? <><td><Link href={`/businesses/${row.id}`}>{row.name}</Link></td><td>{row.city} · {row.area}</td><td><span className="badge">{row.is_active ? 'Active' : row.reviewed_at ? 'Inactive' : 'Pending approval'}</span></td><td><form action={reviewBusiness}><input type="hidden" name="business" value={row.id} /><input type="hidden" name="active" value={String(!row.is_active)} /><button>{row.is_active ? 'Deactivate' : 'Approve & activate'}</button></form></td></> :
            view === 'users' ? <><td><Link href={`/users/${row.id}`}>{row.display_name}</Link></td><td>{row.role}</td><td>{date(row.created_at)}</td></> :
            view === 'reviews' ? <><td><Link href={`/businesses/${row.business_id}`}>View salon</Link><p>{row.employee_id ? `Barber: ${row.employee_id}` : 'Salon review'}</p></td><td><Link href={`/users/${row.author_id}`}>View customer</Link></td><td>{row.rating} / 5<p>{row.body}</p></td><td><form action={deleteReview}><input type="hidden" name="review" value={row.id}/><button>Remove review</button></form></td></> :
            view === 'contracts' ? <><td><Link href={`/users/${row.profile_id}`}>View employee</Link></td><td>{row.kind}</td><td>{date(row.starts_at)} → {date(row.ends_at)}</td><td><span className="badge">{contractStatus(row as { status: string; starts_at: string; ends_at: string | null })}</span>
              {row.status === 'accepted' && (!row.ends_at || new Date(row.ends_at) > new Date()) && <form className="row" action={releaseContract}><input type="hidden" name="contract" value={row.id} /><input name="reason" aria-label="Release reason" placeholder="Reason for release" required maxLength={1000} /><button>Release</button></form>}
              {row.release_reason && <p>{row.release_reason}</p>}</td></> :
              <><td><Link href={`/users/${row.profile_id}`}>View employee</Link></td><td>{row.id}</td><td>{date(row.ends_at)}</td></>}
        </tr>)}</tbody></table>}
    </section><div className="row spread"><span>Page {page + 1}</span><div className="row">
      {page > 0 && <Link href={`/?view=${view}&page=${page - 1}`}>Previous</Link>}
      {(page + 1) * 25 < (count ?? 0) && <Link href={`/?view=${view}&page=${page + 1}`}>Next</Link>}
    </div></div>
  </main></>;
}
