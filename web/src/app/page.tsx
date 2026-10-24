import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/auth';
import { supabaseConfig } from '@/lib/supabase/config';
import { AdminShell } from '@/components/admin-shell';
import { reviewBusiness, releaseContract, deleteReview } from './actions';
import { date, contractStatus } from '@/lib/format';

export const dynamic = 'force-dynamic';

const VIEWS = ['businesses', 'users', 'contracts', 'reminders', 'reviews'] as const;

function statusBadge(isActive: boolean, reviewedAt: string | null) {
  if (isActive) return <span className="badge badge-active">Active</span>;
  if (reviewedAt) return <span className="badge badge-inactive">Inactive</span>;
  return <span className="badge badge-pending">Pending approval</span>;
}

export default async function Home({ searchParams }: {
  searchParams: Promise<{ view?: string; page?: string; message?: string }>;
}) {
  if (!supabaseConfig()) redirect('/login');
  const { client, account } = await requireAdmin();
  const params = await searchParams;
  const view = VIEWS.includes((params.view ?? '') as typeof VIEWS[number])
    ? params.view!
    : 'businesses';
  const page = Math.max(0, Math.min(100000, Number.parseInt(params.page ?? '0') || 0));
  const table =
    view === 'contracts'
      ? 'employee_contracts'
      : view === 'reminders'
        ? 'contract_reminders'
        : view;
  const { data, error, count } = await client
    .from(table)
    .select('*', { count: 'exact' })
    .order(view === 'reminders' ? 'ends_at' : 'created_at', {
      ascending: view === 'reminders',
    })
    .range(page * 25, page * 25 + 24);
  if (error) {
    throw new Error(
      'Could not load administration data. Check the database setup and try again.',
    );
  }
  const rows = data ?? [];
  const total = count ?? 0;

  const titles: Record<string, { title: string; blurb: string }> = {
    businesses: {
      title: 'Businesses',
      blurb: 'Review salon registrations, approve new shops and manage active listings.',
    },
    users: {
      title: 'Users',
      blurb: 'Owners, staff and customers across the TrimMatrix network.',
    },
    contracts: {
      title: 'Contracts',
      blurb: 'Employee agreements, releases and commission terms.',
    },
    reminders: {
      title: 'Ending in 7 days',
      blurb: 'Contracts that need attention before they expire.',
    },
    reviews: {
      title: 'Reviews',
      blurb: 'Moderate salon and barber feedback from customers.',
    },
  };

  const headings =
    view === 'businesses'
      ? ['Business', 'Location', 'Status', 'Action']
      : view === 'users'
        ? ['Name', 'Role', 'Joined']
        : view === 'reviews'
          ? ['Salon / barber', 'Customer', 'Review', 'Moderation']
          : view === 'contracts'
            ? ['Employee', 'Type', 'Period', 'Status / release']
            : ['Employee', 'Contract', 'Ends'];

  return (
    <AdminShell name={account.display_name} activeView={view}>
      <div className="page-head">
        <div className="eyebrow">Dashboard</div>
        <h1>{titles[view].title}</h1>
        <p className="muted">{titles[view].blurb}</p>
      </div>

      {view === 'businesses' && (
        <div className="stats">
          <div className="stat">
            <span>Total</span>
            <strong>{total}</strong>
          </div>
          <div className="stat">
            <span>On this page</span>
            <strong>{rows.length}</strong>
          </div>
          <div className="stat">
            <span>Page</span>
            <strong>{page + 1}</strong>
          </div>
        </div>
      )}

      {params.message && (
        <p className="notice" role="alert">
          The change could not be saved. Refresh the record and try again.
        </p>
      )}

      <section className="panel">
        <div className="panel-head">
          <h2>
            {view === 'reminders' ? 'Upcoming contract expiry' : titles[view].title}
          </h2>
          <span className="muted">{total} records</span>
        </div>
        {!rows.length ? (
          <p className="empty">No records to show.</p>
        ) : (
          <table>
            <thead>
              <tr>
                {headings.map((label) => (
                  <th key={label}>{label}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id}>
                  {view === 'businesses' ? (
                    <>
                      <td>
                        <Link href={`/businesses/${row.id}`}>{row.name}</Link>
                      </td>
                      <td>
                        {row.city} · {row.area}
                      </td>
                      <td>{statusBadge(row.is_active, row.reviewed_at)}</td>
                      <td>
                        <form action={reviewBusiness}>
                          <input type="hidden" name="business" value={row.id} />
                          <input
                            type="hidden"
                            name="active"
                            value={String(!row.is_active)}
                          />
                          <button type="submit">
                            {row.is_active ? 'Deactivate' : 'Approve & activate'}
                          </button>
                        </form>
                      </td>
                    </>
                  ) : view === 'users' ? (
                    <>
                      <td>
                        <Link href={`/users/${row.id}`}>{row.display_name}</Link>
                      </td>
                      <td>{row.role}</td>
                      <td>{date(row.created_at)}</td>
                    </>
                  ) : view === 'reviews' ? (
                    <>
                      <td>
                        <Link href={`/businesses/${row.business_id}`}>View salon</Link>
                        <p className="muted">
                          {row.employee_id
                            ? `Barber: ${row.employee_id}`
                            : 'Salon review'}
                        </p>
                      </td>
                      <td>
                        <Link href={`/users/${row.author_id}`}>View customer</Link>
                      </td>
                      <td>
                        {row.rating} / 5
                        <p className="muted">{row.body}</p>
                      </td>
                      <td>
                        <form action={deleteReview}>
                          <input type="hidden" name="review" value={row.id} />
                          <button type="submit">Remove review</button>
                        </form>
                      </td>
                    </>
                  ) : view === 'contracts' ? (
                    <>
                      <td>
                        <Link href={`/users/${row.profile_id}`}>View employee</Link>
                      </td>
                      <td>{row.kind}</td>
                      <td>
                        {date(row.starts_at)} → {date(row.ends_at)}
                      </td>
                      <td>
                        <span className="badge">
                          {contractStatus(
                            row as {
                              status: string;
                              starts_at: string;
                              ends_at: string | null;
                            },
                          )}
                        </span>
                        {row.status === 'accepted' &&
                          (!row.ends_at || new Date(row.ends_at) > new Date()) && (
                            <form className="row" action={releaseContract}>
                              <input type="hidden" name="contract" value={row.id} />
                              <input
                                name="reason"
                                aria-label="Release reason"
                                placeholder="Reason for release"
                                required
                                maxLength={1000}
                              />
                              <button type="submit">Release</button>
                            </form>
                          )}
                        {row.release_reason && (
                          <p className="muted">{row.release_reason}</p>
                        )}
                      </td>
                    </>
                  ) : (
                    <>
                      <td>
                        <Link href={`/users/${row.profile_id}`}>View employee</Link>
                      </td>
                      <td>{row.id}</td>
                      <td>{date(row.ends_at)}</td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <div className="pager">
        <span className="muted">Page {page + 1}</span>
        <div className="row">
          {page > 0 && (
            <Link href={`/?view=${view}&page=${page - 1}`}>Previous</Link>
          )}
          {(page + 1) * 25 < total && (
            <Link href={`/?view=${view}&page=${page + 1}`}>Next</Link>
          )}
        </div>
      </div>
    </AdminShell>
  );
}
