export type Account = {
  id: string;
  display_name: string;
  role: string;
  created_at: string;
};
export type Profile = {
  user_id: string;
  code: string;
  cnic: string | null;
  date_of_birth: string | null;
  phone: string;
  photo_path: string | null;
  work_started_on: string | null;
};
export type BusinessRecord = {
  id: string;
  owner_id: string;
  name: string;
  phone: string;
  business_type: string;
  city: string;
  area: string;
  address: string;
  logo_path: string | null;
  is_active: boolean;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
};
export type Membership = {
  id: string;
  business_id: string;
  profile_id: string;
  created_at: string;
  join_status: string;
};
export type Contract = {
  id: string;
  employee_id: string;
  profile_id: string;
  kind: string;
  starts_at: string;
  ends_at: string | null;
  salary: number;
  commission_percent: number;
  terms: string;
  status: string;
  release_reason: string | null;
  released_at: string | null;
  created_at: string;
};
export type Review = {
  id: string;
  business_id: string;
  employee_id: string | null;
  author_id: string;
  rating: number;
  body: string;
  created_at: string;
};
export type Service = {
  id: string;
  name: string;
  category: string;
  subcategory: string;
  gender: string;
  age_group: string;
  price: number;
  description: string;
  is_active: boolean;
};

// Account permissions and participation labels are deliberately separate.
export function participation(
  account: Account,
  businesses: BusinessRecord[],
  contracts: Contract[],
  reviews: Review[],
  now = Date.now(),
) {
  const labels: string[] = [];
  if (account.role === 'superadmin') labels.push('Superadmin');
  if (businesses.some((business) => business.owner_id === account.id))
    labels.push('Owner');
  if (
    contracts.some(
      (contract) =>
        contract.profile_id === account.id &&
        contract.status === 'accepted' &&
        new Date(contract.starts_at).getTime() <= now &&
        (!contract.ends_at || new Date(contract.ends_at).getTime() > now),
    )
  )
    labels.push('Employee');
  if (reviews.some((review) => review.author_id === account.id))
    labels.push('Customer');
  return labels.length ? labels : ['Registered user'];
}

export function businessStatus(
  business: Pick<BusinessRecord, 'is_active' | 'reviewed_at'>,
) {
  return business.is_active
    ? 'Active'
    : business.reviewed_at
      ? 'Inactive'
      : 'Pending approval';
}
