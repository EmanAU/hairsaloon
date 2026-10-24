import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/auth';
import { supabaseConfig } from '@/lib/supabase/config';
import { AdminShell } from '@/components/admin-shell';
import {
  BusinessBadge,
  Identity,
  Pager,
  ReviewCards,
  RoleBadges,
} from '@/components/admin-details';
import { allRows, people, reviewContext, userContext } from '@/lib/admin-data';
import {
  participation,
  type Account,
  type BusinessRecord,
  type Contract,
  type Membership,
  type Review,
} from '@/lib/admin-types';
import { releaseContract } from './actions';
import { date, contractStatus } from '@/lib/format';

export const dynamic = 'force-dynamic';
const VIEWS = [
  'businesses',
  'users',
  'contracts',
  'reminders',
  'reviews',
] as const;
const titles = {
  businesses: [
    'Businesses',
    'Review registrations and get to know the people behind each salon.',
  ],
  users: [
    'People & accounts',
    'Owners, employees and customers, with their salon connections in one place.',
  ],
  contracts: ['Contracts', 'Employment agreements, terms and release history.'],
  reminders: [
    'Ending soon',
    'Accepted contracts ending within the next seven days.',
  ],
  reviews: [
    'Customer reviews',
    'See who reviewed each salon and barber, and manage their feedback.',
  ],
};

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{
    view?: string;
    page?: string;
    message?: string;
    q?: string;
    status?: string;
  }>;
}) {
  if (!supabaseConfig()) redirect('/login');
  const { client, account } = await requireAdmin();
  const params = await searchParams;
  const view = VIEWS.includes(params.view as (typeof VIEWS)[number])
    ? (params.view as (typeof VIEWS)[number])
    : 'businesses';
  const page = Math.max(
    0,
    Math.min(100000, Number.parseInt(params.page ?? '0') || 0),
  );
  const q = (params.q ?? '').trim().slice(0, 120);
  const status = ['pending', 'active', 'inactive'].includes(params.status ?? '')
    ? params.status!
    : '';
  const table =
    view === 'contracts'
      ? 'employee_contracts'
      : view === 'reminders'
        ? 'contract_reminders'
        : view;
  let query = client.from(table).select('*', { count: 'exact' });
  if (q && (view === 'users' || view === 'businesses'))
    query = query.ilike(view === 'users' ? 'display_name' : 'name', `%${q}%`);
  if (view === 'businesses') {
    if (status === 'active') query = query.eq('is_active', true);
    if (status === 'pending')
      query = query.eq('is_active', false).is('reviewed_at', null);
    if (status === 'inactive')
      query = query.eq('is_active', false).not('reviewed_at', 'is', null);
  }
  const { data, error, count } = await query
    .order(view === 'reminders' ? 'ends_at' : 'created_at', {
      ascending: view === 'reminders',
    })
    .order('id')
    .range(page * 25, page * 25 + 24);
  if (error)
    throw new Error(
      'Could not load administration data. Refresh and try again.',
    );
  const rows = data ?? [];
  const total = count ?? 0;
  const directory = await people(
    client,
    rows.flatMap((row) =>
      view === 'businesses'
        ? [row.owner_id]
        : view === 'users'
          ? [row.id]
          : view === 'contracts' || view === 'reminders'
            ? [row.profile_id]
            : [],
    ),
  );
  const context = await userContext(
    client,
    view === 'users' ? rows.map((row) => row.id) : [],
  );
  const feedback = await reviewContext(
    client,
    view === 'reviews' ? (rows as Review[]) : [],
  );
  const employeeIds =
    view === 'contracts' ? rows.map((row) => row.employee_id) : [];
  const memberships = employeeIds.length
    ? await allRows<Membership>((from, to) =>
        client
          .from('business_employees')
          .select('*')
          .in('id', employeeIds)
          .order('id')
          .range(from, to),
      )
    : [];
  const salonIds = [
    ...new Set([
      ...context.memberships.map((row) => row.business_id),
      ...memberships.map((row) => row.business_id),
    ]),
  ];
  const connectedSalons = salonIds.length
    ? await allRows<BusinessRecord>((from, to) =>
        client
          .from('businesses')
          .select('*')
          .in('id', salonIds)
          .order('id')
          .range(from, to),
      )
    : [];
  const salonMap = new Map(
    [...context.businesses, ...connectedSalons].map((row) => [row.id, row]),
  );
  const href = (nextPage: number) =>
    `/?${new URLSearchParams({ view, ...(q ? { q } : {}), ...(status ? { status } : {}), page: String(nextPage) })}`;

  return (
    <AdminShell name={account.display_name} activeView={view}>
      <header className="page-head row spread">
        <div>
          <div className="eyebrow">
            Workspace / {view === 'users' ? 'People' : titles[view][0]}
          </div>
          <h1>{titles[view][0]}</h1>
          <p className="muted">{titles[view][1]}</p>
        </div>
        <span className="record-count">
          {total} {view === 'users' ? 'accounts' : 'records'}
        </span>
      </header>
      {params.message && (
        <p
          className={`notice ${params.message === 'saved' ? '' : 'notice-error'}`}
          role="status"
        >
          {params.message === 'saved'
            ? 'Changes saved successfully.'
            : 'The change could not be saved. Refresh the record and try again.'}
        </p>
      )}
      {(view === 'businesses' || view === 'users') && (
        <form className="toolbar" method="get">
          <input type="hidden" name="view" value={view} />
          <div className="search-field">
            <label className="sr-only" htmlFor="search">
              Search {view}
            </label>
            <input
              id="search"
              type="search"
              name="q"
              placeholder={
                view === 'users'
                  ? 'Search people by name…'
                  : 'Search businesses by name…'
              }
              defaultValue={q}
            />
          </div>
          {view === 'businesses' && (
            <>
              <label className="sr-only" htmlFor="status">
                Business status
              </label>
              <select id="status" name="status" defaultValue={status}>
                <option value="">All statuses</option>
                <option value="pending">Pending approval</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </>
          )}
          <button type="submit">Search</button>
          {(q || status) && (
            <Link className="text-link" href={`/?view=${view}`}>
              Clear
            </Link>
          )}
        </form>
      )}

      {view === 'users' ? (
        <>
          <p className="section-caption">
            Labels reflect salon ownership, current employment and review
            activity. Accounts can have more than one label.
          </p>
          {!rows.length ? (
            <section className="panel">
              <p className="empty">No accounts match your search.</p>
            </section>
          ) : (
            <div className="people-grid">
              {(rows as Account[]).map((user) => {
                const profile = directory.profiles.get(user.id);
                const owned = context.businesses.filter(
                  (business) => business.owner_id === user.id,
                );
                const joined = context.memberships.filter(
                  (membership) => membership.profile_id === user.id,
                );
                const labels = participation(
                  user,
                  context.businesses,
                  context.contracts,
                  context.reviews,
                );
                return (
                  <article className="person-card" key={user.id}>
                    <Identity
                      name={user.display_name}
                      subtitle={`Joined ${date(user.created_at)}`}
                      href={`/users/${user.id}`}
                    />
                    <RoleBadges labels={labels} />
                    <dl className="card-facts">
                      <div>
                        <dt>Phone</dt>
                        <dd>{profile?.phone ?? 'Not provided'}</dd>
                      </div>
                      <div>
                        <dt>Profile</dt>
                        <dd>{profile ? 'Created' : 'Not created'}</dd>
                      </div>
                    </dl>
                    <div className="salon-links">
                      {owned.map((business) => (
                        <Link
                          key={business.id}
                          href={`/businesses/${business.id}`}
                        >
                          {business.name}
                          <span>Owner</span>
                        </Link>
                      ))}
                      {joined.slice(0, 2).map((membership) => (
                        <Link
                          key={membership.id}
                          href={`/businesses/${membership.business_id}`}
                        >
                          {salonMap.get(membership.business_id)?.name ??
                            'View salon'}
                          <span>
                            {membership.join_status === 'pending'
                              ? 'Join request pending'
                              : membership.join_status === 'declined'
                                ? 'Join request declined'
                                : 'Membership accepted'}
                          </span>
                        </Link>
                      ))}
                      {!owned.length && !joined.length && (
                        <p className="secondary-text">
                          No salon connections yet
                        </p>
                      )}
                    </div>
                    <Link
                      className="card-footer-link"
                      href={`/users/${user.id}`}
                    >
                      View full profile <span aria-hidden="true">↗</span>
                    </Link>
                  </article>
                );
              })}
            </div>
          )}
        </>
      ) : view === 'reviews' ? (
        <section className="panel">
          <div className="panel-head">
            <h2>Latest feedback</h2>
            <span className="muted">{total} reviews</span>
          </div>
          <ReviewCards
            reviews={rows as Review[]}
            context={feedback}
            returnTo={href(page)}
          />
        </section>
      ) : (
        <section className="panel">
          <div className="panel-head">
            <h2>
              {view === 'businesses' ? 'Salon directory' : titles[view][0]}
            </h2>
            <span className="secondary-text">
              {rows.length
                ? `${page * 25 + 1}–${page * 25 + rows.length} of ${total}`
                : '0 records'}
            </span>
          </div>
          {!rows.length ? (
            <p className="empty">
              {q || status
                ? 'No records match these filters.'
                : 'No records to show yet.'}
            </p>
          ) : (
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    {(view === 'businesses'
                      ? ['Business', 'Owner', 'Status', 'Details']
                      : view === 'contracts'
                        ? [
                            'Employee / salon',
                            'Agreement',
                            'Period',
                            'Status / action',
                          ]
                        : ['Employee', 'Contract', 'Ends']
                    ).map((heading) => (
                      <th key={heading}>{heading}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row) => (
                    <tr key={row.id}>
                      {view === 'businesses' ? (
                        <>
                          <td>
                            <Identity
                              name={row.name}
                              subtitle={`${row.business_type} · ${[row.city, row.area].filter(Boolean).join(', ')}`}
                              href={`/businesses/${row.id}`}
                            />
                            <p className="secondary-text cell-note">
                              {row.phone}
                            </p>
                          </td>
                          <td>
                            <Link href={`/users/${row.owner_id}`}>
                              {directory.accounts.get(row.owner_id)
                                ?.display_name ?? 'View owner'}
                            </Link>
                            <p className="secondary-text">
                              {directory.profiles.get(row.owner_id)?.phone ??
                                'No profile phone'}
                            </p>
                          </td>
                          <td>
                            <BusinessBadge business={row as BusinessRecord} />
                            <p className="secondary-text">
                              Registered {date(row.created_at)}
                            </p>
                          </td>
                          <td>
                            <Link
                              className="button-link button-secondary"
                              href={`/businesses/${row.id}`}
                            >
                              {row.is_active
                                ? 'View details'
                                : 'Review details'}{' '}
                              <span aria-hidden="true">↗</span>
                            </Link>
                          </td>
                        </>
                      ) : view === 'contracts' ? (
                        <>
                          <td>
                            <Link href={`/users/${row.profile_id}`}>
                              {directory.accounts.get(row.profile_id)
                                ?.display_name ?? 'View employee'}
                            </Link>
                            {(() => {
                              const membership = memberships.find(
                                (item) => item.id === row.employee_id,
                              );
                              const salon =
                                membership &&
                                salonMap.get(membership.business_id);
                              return (
                                salon && (
                                  <p className="secondary-text">
                                    <Link href={`/businesses/${salon.id}`}>
                                      {salon.name}
                                    </Link>
                                  </p>
                                )
                              );
                            })()}
                          </td>
                          <td>
                            <span className="capitalize">{row.kind}</span>
                            <p className="secondary-text">
                              Salary {row.salary} · {row.commission_percent}%
                              commission
                            </p>
                          </td>
                          <td>
                            {date(row.starts_at)}
                            <p className="secondary-text">
                              to{' '}
                              {row.ends_at ? date(row.ends_at) : 'No end date'}
                            </p>
                          </td>
                          <td>
                            <span className="badge capitalize">
                              {contractStatus(row as Contract)}
                            </span>
                            {row.status === 'accepted' &&
                              (!row.ends_at ||
                                new Date(row.ends_at) > new Date()) && (
                                <details className="moderation">
                                  <summary>Release contract</summary>
                                  <form
                                    className="release-form"
                                    action={releaseContract}
                                  >
                                    <input
                                      type="hidden"
                                      name="contract"
                                      value={row.id}
                                    />
                                    <input
                                      name="reason"
                                      aria-label="Release reason"
                                      placeholder="Reason for release"
                                      required
                                      maxLength={1000}
                                    />
                                    <button
                                      type="submit"
                                      className="btn-danger"
                                    >
                                      Confirm release
                                    </button>
                                  </form>
                                </details>
                              )}
                            {row.release_reason && (
                              <p className="secondary-text">
                                {row.release_reason}
                              </p>
                            )}
                          </td>
                        </>
                      ) : (
                        <>
                          <td>
                            <Link href={`/users/${row.profile_id}`}>
                              {directory.accounts.get(row.profile_id)
                                ?.display_name ?? 'View employee'}
                            </Link>
                          </td>
                          <td>
                            <Link href={`/users/${row.profile_id}#contracts`}>
                              View agreement
                            </Link>
                          </td>
                          <td>{date(row.ends_at)}</td>
                        </>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}
      <Pager page={page} total={total} href={href} />
    </AdminShell>
  );
}
