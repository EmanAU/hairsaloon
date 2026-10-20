import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/auth';
import { AdminShell } from '@/components/admin-shell';
import { date, contractStatus } from '@/lib/format';

export default async function User({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { client, account } = await requireAdmin();
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const [userResult, profileResult, membershipsResult, contractsResult] =
    await Promise.all([
      client.from('users').select('*').eq('id', id).maybeSingle(),
      client.from('profiles').select('*').eq('user_id', id).maybeSingle(),
      client.from('business_employees').select('id, business_id').eq('profile_id', id),
      client
        .from('employee_contracts')
        .select('*')
        .eq('profile_id', id)
        .order('starts_at', { ascending: false }),
    ]);
  if (
    [userResult, profileResult, membershipsResult, contractsResult].some(
      (result) => result.error,
    )
  ) {
    throw new Error('Could not load user.');
  }
  const user = userResult.data;
  if (!user) notFound();
  const profile = profileResult.data;

  return (
    <AdminShell name={account.display_name} activeView="users">
      <Link className="back" href="/?view=users">
        ← Users
      </Link>
      <div className="page-head">
        <div className="eyebrow">User detail</div>
        <h1>{user.display_name}</h1>
      </div>

      <section className="panel">
        <div className="panel-head">
          <h2>Account & profile</h2>
        </div>
        <dl>
          <dt>Role</dt>
          <dd>{user.role}</dd>
          <dt>Joined</dt>
          <dd>{date(user.created_at)}</dd>
          {profile && (
            <>
              <dt>Profile code</dt>
              <dd>{profile.code}</dd>
              <dt>CNIC</dt>
              <dd>{profile.cnic ?? '—'}</dd>
              <dt>Date of birth</dt>
              <dd>{date(profile.date_of_birth)}</dd>
              <dt>Mobile</dt>
              <dd>{profile.phone}</dd>
            </>
          )}
        </dl>
        {!profile && (
          <p className="muted">This user has not created a personal profile yet.</p>
        )}
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>Salon memberships</h2>
        </div>
        {membershipsResult.data?.length ? (
          membershipsResult.data.map((membership) => (
            <p key={membership.id}>
              <Link href={`/businesses/${membership.business_id}`}>
                View salon · {membership.business_id}
              </Link>
            </p>
          ))
        ) : (
          <p className="empty">No memberships yet.</p>
        )}
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>Contract history</h2>
        </div>
        {contractsResult.data?.length ? (
          <table>
            <thead>
              <tr>
                <th>Type / terms</th>
                <th>Period</th>
                <th>Salary / commission</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {contractsResult.data.map((contract) => (
                <tr key={contract.id}>
                  <td>
                    {contract.kind}
                    <p className="muted">{contract.terms}</p>
                  </td>
                  <td>
                    {date(contract.starts_at)} → {date(contract.ends_at)}
                  </td>
                  <td>
                    {contract.salary} / {contract.commission_percent}%
                  </td>
                  <td>
                    {contractStatus(contract)}
                    {contract.release_reason && (
                      <p className="muted">
                        {contract.release_reason} · {date(contract.released_at)}
                      </p>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p className="empty">No contracts yet.</p>
        )}
      </section>
    </AdminShell>
  );
}
