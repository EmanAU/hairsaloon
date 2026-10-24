'use server';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/auth';

function returnPath(form: FormData, fallback: string) {
  const path = String(form.get('returnTo') ?? '');
  // Only these local admin routes are valid redirect destinations.
  return /^\/(?:\?(?:[^#]*))?$/.test(path) ||
    /^\/(?:businesses|users)\/[0-9a-f-]{36}(?:\?[^#]*)?$/i.test(path)
    ? path
    : fallback;
}

function withMessage(path: string, message: string) {
  const url = new URL(path, 'http://localhost');
  url.searchParams.set('message', message);
  return `${url.pathname}${url.search}`;
}

export async function reviewBusiness(form: FormData) {
  const { client } = await requireAdmin();
  const business = String(form.get('business') ?? '');
  const active = form.get('active');
  if (
    !/^[0-9a-f-]{36}$/i.test(business) ||
    !['true', 'false'].includes(String(active))
  ) {
    throw new Error('Invalid business review.');
  }
  const { error } = await client.rpc('review_business', {
    business,
    active: active === 'true',
  });
  const destination = returnPath(form, `/businesses/${business}`);
  if (error) redirect(withMessage(destination, 'review-failed'));
  revalidatePath('/');
  revalidatePath(`/businesses/${business}`);
  redirect(withMessage(destination, 'saved'));
}

export async function releaseContract(form: FormData) {
  const { client } = await requireAdmin();
  const contract = String(form.get('contract') ?? '');
  const reason = String(form.get('reason') ?? '').trim();
  if (!/^[0-9a-f-]{36}$/i.test(contract) || !reason || reason.length > 1000) {
    throw new Error('A valid contract and release reason are required.');
  }
  const { error } = await client.rpc('release_contract', { contract, reason });
  if (error) redirect('/?view=contracts&message=release-failed');
  revalidatePath('/');
}

export async function deleteReview(form: FormData) {
  const { client } = await requireAdmin();
  const id = String(form.get('review') ?? '');
  if (!/^[0-9a-f-]{36}$/i.test(id)) throw new Error('Invalid review.');
  const { data: review, error: lookupError } = await client
    .from('reviews')
    .select('business_id, author_id')
    .eq('id', id)
    .maybeSingle();
  const destination = returnPath(form, '/?view=reviews');
  if (lookupError || !review)
    redirect(withMessage(destination, 'delete-failed'));
  const { error } = await client.from('reviews').delete().eq('id', id);
  if (error) redirect(withMessage(destination, 'delete-failed'));
  revalidatePath('/');
  revalidatePath(`/businesses/${review.business_id}`);
  revalidatePath(`/users/${review.author_id}`);
  redirect(withMessage(destination, 'saved'));
}
