import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/auth';
import { AdminShell } from '@/components/admin-shell';
import {
  BusinessBadge,
  Details,
  Identity,
  ReviewCards,
  RoleBadges,
} from '@/components/admin-details';
import { allRows, reviewContext, userContext } from '@/lib/admin-data';
import {
  participation,
  type Account,
  type BusinessRecord,
} from '@/lib/admin-types';
import { date, contractStatus } from '@/lib/format';

export default async function User({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ message?: string }>;
}) {
  const { client, account } = await requireAdmin();
  const { id } = await params;
  const { message } = await searchParams;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const [userResult, profileResult, context] = await Promise.all([
    client.from('users').select('*').eq('id', id).maybeSingle(),
    client.from('profiles').select('*').eq('user_id', id).maybeSingle(),
    userContext(client, [id]),
  ]);
  if (userResult.error || profileResult.error)
    throw new Error('Could not load this profile. Please try again.');
  if (!userResult.data) notFound();
  const user = userResult.data as Account;
  const profile = profileResult.data;
  const salonIds = [
    ...new Set(context.memberships.map((membership) => membership.business_id)),
  ];
  const [salons, photoResult, feedback] = await Promise.all([
    salonIds.length
      ? allRows<BusinessRecord>((from, to) =>
          client
            .from('businesses')
            .select('*')
            .in('id', salonIds)
            .order('id')
            .range(from, to),
        )
      : [],
    profile?.photo_path
      ? client.storage
          .from('profile-photos')
          .createSignedUrl(profile.photo_path, 3600)
      : null,
    reviewContext(client, context.reviews),
  ]);
  const salonMap = new Map(salons.map((business) => [business.id, business]));

  return (
    <AdminShell name={account.display_name} activeView="users">
      <Link className="back" href="/?view=users">
        ← All people
      </Link>
      {message && (
        <p
          className={`notice ${message === 'saved' ? '' : 'notice-error'}`}
          role="status"
        >
          {message === 'saved'
            ? 'Changes saved successfully.'
            : 'The change could not be saved. Refresh and try again.'}
        </p>
      )}
      <header className="page-head">
        <div className="eyebrow">Account profile</div>
        <div className="row spread">
          <Identity
            heading
            name={user.display_name}
            subtitle={`Joined ${date(user.created_at)}`}
            photo={photoResult?.data?.signedUrl}
          />
          <RoleBadges
            labels={participation(
              user,
              context.businesses,
              context.contracts,
              context.reviews,
            )}
          />
        </div>
      </header>
      <nav className="section-nav" aria-label="Profile sections">
        <a href="#profile">Personal details</a>
        <a href="#businesses">
          Businesses <span>{context.businesses.length}</span>
        </a>
        <a href="#memberships">
          Memberships <span>{context.memberships.length}</span>
        </a>
        <a href="#contracts">
          Contracts <span>{context.contracts.length}</span>
        </a>
        <a href="#reviews">
          Reviews <span>{context.reviews.length}</span>
        </a>
      </nav>
      <section className="panel" id="profile">
        <div className="panel-head">
          <h2>Personal & account details</h2>
          <span className="badge badge-inactive">
            {user.role === 'superadmin'
              ? 'Administrator access'
              : 'Standard account'}
          </span>
        </div>
        <Details
          items={[
            ['Full name', user.display_name],
            [
              'Mobile',
              profile?.phone ? (
                <a key="phone" href={`tel:${profile.phone}`}>
                  {profile.phone}
                </a>
              ) : null,
            ],
            ['CNIC', profile?.cnic],
            [
              'Date of birth',
              profile?.date_of_birth ? date(profile.date_of_birth) : null,
            ],
            [
              'Work started',
              profile?.work_started_on ? date(profile.work_started_on) : null,
            ],
            ['Profile code', profile?.code],
            ['Account joined', date(user.created_at)],
            ['Account ID', user.id],
          ]}
        />
        {!profile && (
          <p className="notice">Personal profile has not been created yet.</p>
        )}
      </section>
      <section className="panel" id="businesses">
        <div className="panel-head">
          <h2>Owned businesses</h2>
          <span className="secondary-text">
            {context.businesses.length} businesses
          </span>
        </div>
        {context.businesses.length ? (
          <div className="connection-list">
            {context.businesses.map((business) => (
              <div className="row spread" key={business.id}>
                <Identity
                  name={business.name}
                  subtitle={`${business.business_type} · ${business.city}, ${business.area}`}
                  href={`/businesses/${business.id}`}
                />
                <BusinessBadge business={business} />
              </div>
            ))}
          </div>
        ) : (
          <p className="empty">This account does not own a business.</p>
        )}
      </section>
      <section className="panel" id="memberships">
        <div className="panel-head">
          <h2>Salon memberships & requests</h2>
        </div>
        {context.memberships.length ? (
          <div className="connection-list">
            {context.memberships.map((membership) => {
              const business = salonMap.get(membership.business_id);
              const working = context.contracts.some(
                (contract) =>
                  contract.employee_id === membership.id &&
                  contractStatus(contract) === 'active',
              );
              return (
                <div key={membership.id} className="row spread">
                  <Identity
                    name={business?.name ?? 'Unavailable salon'}
                    subtitle={`Requested ${date(membership.created_at)}`}
                    href={`/businesses/${membership.business_id}`}
                  />
                  <div className="badges">
                    <span className="badge badge-inactive capitalize">
                      Join request: {membership.join_status}
                    </span>
                    <span
                      className={`badge ${working ? 'badge-active' : 'badge-inactive'}`}
                    >
                      {working ? 'Currently working' : 'No active employment'}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <p className="empty">No salon memberships or join requests yet.</p>
        )}
      </section>
      <section className="panel" id="contracts">
        <div className="panel-head">
          <h2>Contract history</h2>
          <span className="secondary-text">
            {context.contracts.length} agreements
          </span>
        </div>
        {context.contracts.length ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Salon / agreement</th>
                  <th>Period</th>
                  <th>Compensation</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {[...context.contracts]
                  .sort((a, b) => b.starts_at.localeCompare(a.starts_at))
                  .map((contract) => {
                    const membership = context.memberships.find(
                      (row) => row.id === contract.employee_id,
                    );
                    const business =
                      membership && salonMap.get(membership.business_id);
                    return (
                      <tr key={contract.id}>
                        <td>
                          {business && (
                            <Link href={`/businesses/${business.id}`}>
                              {business.name}
                            </Link>
                          )}
                          <p className="capitalize">{contract.kind}</p>
                          <p className="secondary-text preserve-lines">
                            {contract.terms || 'No additional terms'}
                          </p>
                        </td>
                        <td>
                          {date(contract.starts_at)}
                          <p className="secondary-text">
                            to{' '}
                            {contract.ends_at
                              ? date(contract.ends_at)
                              : 'No end date'}
                          </p>
                        </td>
                        <td>
                          Salary {contract.salary}
                          <p className="secondary-text">
                            {contract.commission_percent}% commission
                          </p>
                        </td>
                        <td>
                          <span
                            className={`badge capitalize ${contractStatus(contract) === 'active' ? 'badge-active' : 'badge-inactive'}`}
                          >
                            {contractStatus(contract)}
                          </span>
                          {contract.release_reason && (
                            <p className="secondary-text preserve-lines">
                              {contract.release_reason} ·{' '}
                              {date(contract.released_at)}
                            </p>
                          )}
                        </td>
                      </tr>
                    );
                  })}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="empty">No contracts yet.</p>
        )}
      </section>
      <section className="panel" id="reviews">
        <div className="panel-head">
          <h2>Reviews written by {user.display_name}</h2>
          <span className="secondary-text">
            {context.reviews.length} reviews
          </span>
        </div>
        <ReviewCards
          reviews={[...context.reviews].sort((a, b) =>
            b.created_at.localeCompare(a.created_at),
          )}
          context={feedback}
          returnTo={`/users/${id}`}
        />
      </section>
    </AdminShell>
  );
}
