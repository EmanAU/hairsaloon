'use server';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/auth';

export async function reviewBusiness(form: FormData) {
  const { client } = await requireAdmin();
  const business = String(form.get('business') ?? '');
  const active = form.get('active');
  if (!/^[0-9a-f-]{36}$/i.test(business) || !['true', 'false'].includes(String(active))) {
    throw new Error('Invalid business review.');
  }
  const { error } = await client.rpc('review_business', { business, active: active === 'true' });
  if (error) redirect('/?message=review-failed');
  revalidatePath('/');
  revalidatePath(`/businesses/${business}`);
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
  const { error } = await client.from('reviews').delete().eq('id', id);
  if (error) redirect('/?view=reviews&message=delete-failed');
  revalidatePath('/');
}
