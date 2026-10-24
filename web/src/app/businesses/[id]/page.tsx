import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/auth';
import { AdminShell } from '@/components/admin-shell';
import {
  BusinessBadge,
  Details,
  Identity,
  Pager,
  Rating,
  ReviewCards,
} from '@/components/admin-details';
import { reviewBusiness } from '@/app/actions';
import { allRows, people, reviewContext } from '@/lib/admin-data';
import type {
  BusinessRecord,
  Contract,
  Membership,
  Review,
  Service,
} from '@/lib/admin-types';
import { date, contractStatus } from '@/lib/format';

export default async function Business({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ reviewsPage?: string; message?: string }>;
}) {
  const { client, account } = await requireAdmin();
  const { id } = await params;
  const filters = await searchParams;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const page = Math.max(
    0,
    Math.min(100000, Number.parseInt(filters.reviewsPage ?? '0') || 0),
  );
  const [
    businessResult,
    employees,
    services,
    reviewResult,
    ratings,
    inviteResult,
  ] = await Promise.all([
    client.from('businesses').select('*').eq('id', id).maybeSingle(),
    allRows<Membership>((from, to) =>
      client
        .from('business_employees')
        .select('*')
        .eq('business_id', id)
        .order('created_at', { ascending: false })
        .order('id')
        .range(from, to),
    ),
    allRows<Service>((from, to) =>
      client
        .from('services')
        .select('*')
        .eq('business_id', id)
        .order('name')
        .order('id')
        .range(from, to),
    ),
    client
      .from('reviews')
      .select('*', { count: 'exact' })
      .eq('business_id', id)
      .order('created_at', { ascending: false })
      .order('id')
      .range(page * 10, page * 10 + 9),
    allRows<{ rating: number }>((from, to) =>
      client
        .from('reviews')
        .select('rating')
        .eq('business_id', id)
        .order('id')
        .range(from, to),
    ),
    client
      .from('business_invites')
      .select('code')
      .eq('business_id', id)
      .maybeSingle(),
  ]);
  if (businessResult.error || reviewResult.error || inviteResult.error)
    throw new Error('Could not load business details. Please try again.');
  if (!businessResult.data) notFound();
  const business = businessResult.data as BusinessRecord;
  const reviews = (reviewResult.data ?? []) as Review[];
  const employeeIds = employees.map((employee) => employee.id);
  const [directory, feedback, contracts, photoResult] = await Promise.all([
    people(client, [
      business.owner_id,
      business.reviewed_by,
      ...employees.map((employee) => employee.profile_id),
    ]),
    reviewContext(client, reviews),
    employeeIds.length
      ? allRows<Contract>((from, to) =>
          client
            .from('employee_contracts')
            .select('*')
            .in('employee_id', employeeIds)
            .order('starts_at', { ascending: false })
            .order('id')
            .range(from, to),
        )
      : [],
    business.logo_path
      ? client.storage
          .from('business-photos')
          .createSignedUrl(business.logo_path, 3600)
      : null,
  ]);
  const owner = directory.accounts.get(business.owner_id);
  const profile = directory.profiles.get(business.owner_id);
  const ownerPhoto = profile?.photo_path
    ? await client.storage
        .from('profile-photos')
        .createSignedUrl(profile.photo_path, 3600)
    : null;
  const activeEmployees = new Set(
    contracts
      .filter((contract) => contractStatus(contract) === 'active')
      .map((contract) => contract.employee_id),
  );
  const average = ratings.length
    ? ratings.reduce((sum, review) => sum + review.rating, 0) / ratings.length
    : null;
  const returnTo = `/businesses/${id}?reviewsPage=${page}`;

  return (
    <AdminShell name={account.display_name} activeView="businesses">
      <Link className="back" href="/?view=businesses">
        ← All businesses
      </Link>
      <header className="page-head row spread">
        <Identity
          heading
          name={business.name}
          subtitle={`${business.business_type} · ${[business.city, business.area].filter(Boolean).join(', ')}`}
          photo={photoResult?.data?.signedUrl}
        />
        <BusinessBadge business={business} />
      </header>
      {filters.message && (
        <p
          className={`notice ${filters.message === 'saved' ? '' : 'notice-error'}`}
          role="status"
        >
          {filters.message === 'saved'
            ? 'Business status updated successfully.'
            : 'The change could not be saved. Refresh and try again.'}
        </p>
      )}
      <nav className="section-nav" aria-label="Business sections">
        <a href="#overview">Overview & owner</a>
        <a href="#team">
          Team <span>{employees.length}</span>
        </a>
        <a href="#services">
          Services <span>{services.length}</span>
        </a>
        <a href="#reviews">
          Reviews <span>{reviewResult.count ?? 0}</span>
        </a>
      </nav>
      <div className="stats detail-stats">
        <div className="stat">
          <span>Working employees</span>
          <strong>{activeEmployees.size}</strong>
        </div>
        <div className="stat">
          <span>Published services</span>
          <strong>
            {services.filter((service) => service.is_active).length}
          </strong>
        </div>
        <div className="stat">
          <span>Feedback average · {ratings.length} reviews</span>
          <strong>
            {average !== null ? `${average.toFixed(1)} / 5` : 'No ratings'}
          </strong>
        </div>
      </div>

      <div className="detail-grid" id="overview">
        <section className="panel">
          <div className="panel-head">
            <h2>Business information</h2>
          </div>
          <Details
            items={[
              ['Business name', business.name],
              ['Business type', business.business_type],
              [
                'Business phone',
                <a key="phone" href={`tel:${business.phone}`}>
                  {business.phone}
                </a>,
              ],
              ['City', business.city],
              ['Area', business.area],
              ['Full address', business.address],
              ['Registered', date(business.created_at)],
              ['Joining code', inviteResult.data?.code],
              ['Last reviewed', date(business.reviewed_at)],
              [
                'Reviewed by',
                business.reviewed_by ? (
                  <Link key="reviewer" href={`/users/${business.reviewed_by}`}>
                    {directory.accounts.get(business.reviewed_by)
                      ?.display_name ?? 'View administrator'}
                  </Link>
                ) : (
                  'Awaiting review'
                ),
              ],
            ]}
          />
        </section>
        <section className="panel">
          <div className="panel-head">
            <h2>Owner information</h2>
            <Link className="text-link" href={`/users/${business.owner_id}`}>
              Full profile ↗
            </Link>
          </div>
          <Identity
            name={owner?.display_name ?? 'Unavailable account'}
            subtitle="Business owner"
            href={`/users/${business.owner_id}`}
            photo={ownerPhoto?.data?.signedUrl}
          />
          <Details
            items={[
              ['Name', owner?.display_name],
              [
                'Mobile',
                profile?.phone ? (
                  <a key="mobile" href={`tel:${profile.phone}`}>
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
              ['Account joined', owner ? date(owner.created_at) : null],
            ]}
          />
          {!profile && (
            <p className="notice">
              The owner has not created a personal profile yet.
            </p>
          )}
        </section>
      </div>
      <section className="approval-panel">
        <div>
          <h2>
            {business.is_active
              ? 'Business is active'
              : business.reviewed_at
                ? 'Reactivate this business'
                : 'Ready to review this registration?'}
          </h2>
          <p className="muted">
            {business.is_active
              ? 'Deactivating removes this salon from customer discovery.'
              : 'Check the business and owner information above before activating the salon.'}
          </p>
        </div>
        <form action={reviewBusiness}>
          <input type="hidden" name="business" value={id} />
          <input
            type="hidden"
            name="active"
            value={String(!business.is_active)}
          />
          <input type="hidden" name="returnTo" value={`/businesses/${id}`} />
          <button
            className={business.is_active ? 'btn-danger' : ''}
            type="submit"
          >
            {business.is_active ? 'Deactivate business' : 'Approve & activate'}
          </button>
        </form>
      </section>

      <section className="panel" id="team">
        <div className="panel-head">
          <h2>Team & join requests</h2>
          <span className="secondary-text">
            {activeEmployees.size} working ·{' '}
            {
              employees.filter((employee) => employee.join_status === 'pending')
                .length
            }{' '}
            pending requests
          </span>
        </div>
        {!employees.length ? (
          <p className="empty">No employee memberships or join requests yet.</p>
        ) : (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Person</th>
                  <th>Contact</th>
                  <th>Join request</th>
                  <th>Employment</th>
                  <th>Requested</th>
                </tr>
              </thead>
              <tbody>
                {employees.map((employee) => {
                  const person = directory.accounts.get(employee.profile_id);
                  const current = contracts.find(
                    (contract) =>
                      contract.employee_id === employee.id &&
                      contractStatus(contract) === 'active',
                  );
                  const latest =
                    current ??
                    contracts.find(
                      (contract) => contract.employee_id === employee.id,
                    );
                  return (
                    <tr key={employee.id}>
                      <td>
                        <Identity
                          name={person?.display_name ?? 'Unavailable account'}
                          href={`/users/${employee.profile_id}`}
                        />
                      </td>
                      <td>
                        {directory.profiles.get(employee.profile_id)?.phone ??
                          'Not provided'}
                      </td>
                      <td>
                        <span
                          className={`badge capitalize ${employee.join_status === 'pending' ? 'badge-pending' : 'badge-inactive'}`}
                        >
                          {employee.join_status}
                        </span>
                      </td>
                      <td>
                        <span
                          className={`badge capitalize ${current ? 'badge-active' : 'badge-inactive'}`}
                        >
                          {latest ? contractStatus(latest) : 'No contract'}
                        </span>
                        <Link
                          className="secondary-text block"
                          href={`/users/${employee.profile_id}#contracts`}
                        >
                          View agreements ↗
                        </Link>
                      </td>
                      <td>{date(employee.created_at)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <section className="panel" id="services">
        <div className="panel-head">
          <h2>Services & rate list</h2>
          <span className="secondary-text">{services.length} services</span>
        </div>
        {!services.length ? (
          <p className="empty">No services added yet.</p>
        ) : (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Service</th>
                  <th>Category</th>
                  <th>Audience</th>
                  <th>Price</th>
                  <th>Visibility</th>
                </tr>
              </thead>
              <tbody>
                {services.map((service) => (
                  <tr key={service.id}>
                    <td>
                      <strong>{service.name}</strong>
                      <p className="secondary-text service-description">
                        {service.description}
                      </p>
                    </td>
                    <td>
                      {service.category}
                      <p className="secondary-text">{service.subcategory}</p>
                    </td>
                    <td>
                      {[service.gender, service.age_group]
                        .filter(Boolean)
                        .join(' · ') || 'All customers'}
                    </td>
                    <td>
                      {new Intl.NumberFormat('en-PK', {
                        minimumFractionDigits: 0,
                        maximumFractionDigits: 2,
                      }).format(service.price)}
                    </td>
                    <td>
                      <span
                        className={`badge ${service.is_active ? 'badge-active' : 'badge-inactive'}`}
                      >
                        {service.is_active ? 'Published' : 'Hidden'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <section className="panel" id="reviews">
        <div className="panel-head">
          <div>
            <h2>Salon & barber reviews</h2>
            <p className="secondary-text">
              Customer feedback for {business.name}
            </p>
          </div>
          {average !== null && (
            <Rating rating={Math.round(average * 10) / 10} />
          )}
        </div>
        <ReviewCards
          reviews={reviews}
          context={feedback}
          returnTo={returnTo}
          showSalon={false}
        />
        <Pager
          page={page}
          total={reviewResult.count ?? 0}
          size={10}
          href={(nextPage) =>
            `/businesses/${id}?reviewsPage=${nextPage}#reviews`
          }
        />
      </section>
    </AdminShell>
  );
}
