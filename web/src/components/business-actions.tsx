'use client';

import { useFormStatus } from 'react-dom';
import { reviewBusiness } from '@/app/actions';

type Props = {
  business: { id: string; name: string; is_active: boolean; reviewed_at: string | null };
  returnTo: string;
};

function Buttons({ business }: Pick<Props, 'business'>) {
  const { pending } = useFormStatus();
  const approveLabel = 'Activate';
  const rejectLabel = business.is_active ? 'Deactivate' : 'Reject';
  return (
    <>
      {!business.is_active && (
        <button type="submit" name="active" value="true" className="btn-activate" disabled={pending}
          aria-label={`${approveLabel} ${business.name}`}>
          <span aria-hidden="true">✓</span> {approveLabel}
        </button>
      )}
      {(business.is_active || !business.reviewed_at) && (
        <button type="submit" name="active" value="false" className="btn-danger"
          disabled={pending} aria-label={`${rejectLabel} ${business.name}`}>
          <span aria-hidden="true">✕</span> {rejectLabel}
        </button>
      )}
      {pending && <span role="status" className="secondary-text">Saving…</span>}
    </>
  );
}

export function BusinessActions({ business, returnTo }: Props) {
  return (
    <form action={reviewBusiness} className="business-actions">
      <input type="hidden" name="business" value={business.id} />
      <input type="hidden" name="returnTo" value={returnTo} />
      <Buttons business={business} />
    </form>
  );
}
