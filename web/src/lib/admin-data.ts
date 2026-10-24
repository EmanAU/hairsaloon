import 'server-only';
import type { SupabaseClient } from '@supabase/supabase-js';
import type {
  Account,
  Profile,
  BusinessRecord,
  Membership,
  Contract,
  Review,
} from './admin-types';

type QueryResult<T> = { data: T[] | null; error: { message: string } | null };

// Read every matching row, including installations above PostgREST's row limit.
export async function allRows<T>(
  query: (from: number, to: number) => PromiseLike<QueryResult<T>>,
) {
  const rows: T[] = [];
  for (let from = 0; ; from += 500) {
    const result = await query(from, from + 499);
    if (result.error)
      throw new Error(
        'Could not load administration details. Please try again.',
      );
    rows.push(...(result.data ?? []));
    if ((result.data?.length ?? 0) < 500) return rows;
  }
}

export async function people(
  client: SupabaseClient,
  values: (string | null | undefined)[],
) {
  const ids = [...new Set(values.filter((value): value is string => !!value))];
  if (!ids.length)
    return {
      accounts: new Map<string, Account>(),
      profiles: new Map<string, Profile>(),
    };
  const [accounts, profiles] = await Promise.all([
    allRows<Account>((from, to) =>
      client
        .from('users')
        .select('*')
        .in('id', ids)
        .order('id')
        .range(from, to),
    ),
    allRows<Profile>((from, to) =>
      client
        .from('profiles')
        .select('*')
        .in('user_id', ids)
        .order('user_id')
        .range(from, to),
    ),
  ]);
  return {
    accounts: new Map(accounts.map((row) => [row.id, row])),
    profiles: new Map(profiles.map((row) => [row.user_id, row])),
  };
}

export async function userContext(client: SupabaseClient, ids: string[]) {
  if (!ids.length)
    return { businesses: [], memberships: [], contracts: [], reviews: [] } as {
      businesses: BusinessRecord[];
      memberships: Membership[];
      contracts: Contract[];
      reviews: Review[];
    };
  const [businesses, memberships, contracts, reviews] = await Promise.all([
    allRows<BusinessRecord>((from, to) =>
      client
        .from('businesses')
        .select('*')
        .in('owner_id', ids)
        .order('id')
        .range(from, to),
    ),
    allRows<Membership>((from, to) =>
      client
        .from('business_employees')
        .select('*')
        .in('profile_id', ids)
        .order('id')
        .range(from, to),
    ),
    allRows<Contract>((from, to) =>
      client
        .from('employee_contracts')
        .select('*')
        .in('profile_id', ids)
        .order('id')
        .range(from, to),
    ),
    allRows<Review>((from, to) =>
      client
        .from('reviews')
        .select('*')
        .in('author_id', ids)
        .order('id')
        .range(from, to),
    ),
  ]);
  return { businesses, memberships, contracts, reviews };
}

export async function reviewContext(client: SupabaseClient, reviews: Review[]) {
  const businessIds = [...new Set(reviews.map((review) => review.business_id))];
  const employeeIds = [
    ...new Set(
      reviews.flatMap((review) =>
        review.employee_id ? [review.employee_id] : [],
      ),
    ),
  ];
  const [businesses, memberships] = await Promise.all([
    businessIds.length
      ? allRows<BusinessRecord>((from, to) =>
          client
            .from('businesses')
            .select('*')
            .in('id', businessIds)
            .order('id')
            .range(from, to),
        )
      : [],
    employeeIds.length
      ? allRows<Membership>((from, to) =>
          client
            .from('business_employees')
            .select('*')
            .in('id', employeeIds)
            .order('id')
            .range(from, to),
        )
      : [],
  ]);
  const directory = await people(client, [
    ...reviews.map((review) => review.author_id),
    ...memberships.map((membership) => membership.profile_id),
  ]);
  return {
    ...directory,
    businesses: new Map(businesses.map((row) => [row.id, row])),
    memberships: new Map(memberships.map((row) => [row.id, row])),
  };
}
