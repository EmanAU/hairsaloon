import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/auth';
import { Header } from '@/components/header';
import { reviewBusiness } from '@/app/actions';
import { date } from '@/lib/format';

export default async function Business({ params }: { params: Promise<{ id: string }> }) {
  const { client, account } = await requireAdmin();
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const [businessResult, employeesResult, servicesResult] = await Promise.all([
    client.from('businesses').select('*').eq('id', id).maybeSingle(),
    client.from('business_employees').select('id, profile_id, created_at').eq('business_id', id).order('created_at', { ascending: false }),
    client.from('services').select('id, name, price, description, is_active, category').eq('business_id', id).order('name'),
  ]);
  if (businessResult.error || employeesResult.error || servicesResult.error) throw new Error('Could not load business.');
  const business = businessResult.data;
  if (!business) notFound();
  return <><Header name={account.display_name} /><main><Link href="/">← Businesses</Link>
    <h1>{business.name}</h1><p className="muted">{business.city} · {business.area}</p>
    <section className="panel"><div className="row spread"><h2>Business details</h2><form action={reviewBusiness}>
      <input type="hidden" name="business" value={id} /><input type="hidden" name="active" value={String(!business.is_active)} />
      <button>{business.is_active ? 'Deactivate business' : 'Approve & activate'}</button></form></div>
      <dl><dt>Status</dt><dd>{business.is_active ? 'Active' : business.reviewed_at ? 'Inactive' : 'Pending approval'}</dd>
        <dt>Owner</dt><dd><Link href={`/users/${business.owner_id}`}>View owner</Link></dd>
        <dt>Type</dt><dd>{business.business_type}</dd><dt>Phone</dt><dd>{business.phone}</dd>
        <dt>Address</dt><dd>{business.address}</dd><dt>Registered</dt><dd>{date(business.created_at)}</dd>
        <dt>Last reviewed</dt><dd>{date(business.reviewed_at)}</dd></dl>
    </section>
    <section className="panel"><h2>Employee memberships</h2><p className="muted">A membership may be pending; accepted contracts determine employment.</p>
      {!employeesResult.data?.length ? <p>No employees yet.</p> : <table><thead><tr><th>Profile</th><th>Requested</th></tr></thead><tbody>
        {employeesResult.data.map(employee => <tr key={employee.id}><td><Link href={`/users/${employee.profile_id}`}>View profile & contracts</Link></td><td>{date(employee.created_at)}</td></tr>)}
      </tbody></table>}
    </section>
    <section className="panel"><h2>Rate list</h2>{!servicesResult.data?.length ? <p>No services yet.</p> : <table><thead><tr><th>Service</th><th>Category</th><th>Price</th><th>Status</th></tr></thead><tbody>
      {servicesResult.data.map(service => <tr key={service.id}><td>{service.name}<p className="muted">{service.description}</p></td><td>{service.category}</td><td>{service.price}</td><td>{service.is_active ? 'Active' : 'Hidden'}</td></tr>)}
    </tbody></table>}</section>
  </main></>;
}
