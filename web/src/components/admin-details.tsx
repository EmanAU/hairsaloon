import Link from 'next/link';
import type { ReactNode } from 'react';
import { date } from '@/lib/format';
import {
  businessStatus,
  type BusinessRecord,
  type Review,
} from '@/lib/admin-types';
import type { reviewContext } from '@/lib/admin-data';
import { deleteReview } from '@/app/actions';

export function BusinessBadge({
  business,
}: {
  business: Pick<BusinessRecord, 'is_active' | 'reviewed_at'>;
}) {
  return (
    <span
      className={`badge ${business.is_active ? 'badge-active' : business.reviewed_at ? 'badge-inactive' : 'badge-pending'}`}
    >
      {businessStatus(business)}
    </span>
  );
}

export function RoleBadges({ labels }: { labels: string[] }) {
  return (
    <div className="badges">
      {labels.map((label) => (
        <span
          key={label}
          className={`badge role-${label.toLowerCase().replaceAll(' ', '-')}`}
        >
          {label}
        </span>
      ))}
    </div>
  );
}

export function Identity({
  name,
  subtitle,
  href,
  photo,
  heading = false,
}: {
  name: string;
  subtitle?: string;
  href?: string;
  photo?: string | null;
  heading?: boolean;
}) {
  return (
    <div className="identity">
      <div className="avatar" aria-hidden="true">
        {photo ? (
          <img src={photo} alt="" />
        ) : (
          name.trim().slice(0, 2).toUpperCase()
        )}
      </div>
      <div className="identity-copy">
        {heading ? (
          <h1 className="record-name">{name}</h1>
        ) : href ? (
          <Link className="record-name" href={href}>
            {name}
          </Link>
        ) : (
          <strong className="record-name">{name}</strong>
        )}
        {subtitle && <span className="secondary-text">{subtitle}</span>}
      </div>
    </div>
  );
}

export function Details({ items }: { items: [string, ReactNode][] }) {
  return (
    <dl className="detail-list">
      {items.map(([label, value]) => (
        <div key={label}>
          <dt>{label}</dt>
          <dd>{value || 'Not provided'}</dd>
        </div>
      ))}
    </dl>
  );
}

export function Rating({ rating }: { rating: number }) {
  return (
    <span className="rating" aria-label={`${rating} out of 5 stars`}>
      <span aria-hidden="true">
        {'★'.repeat(Math.round(rating))}
        <span className="unfilled">{'★'.repeat(5 - Math.round(rating))}</span>
      </span>
      <strong>{rating.toFixed(1)}</strong>
      <span className="secondary-text">/ 5</span>
    </span>
  );
}

export function ReviewCards({
  reviews,
  context,
  returnTo,
  showSalon = true,
}: {
  reviews: Review[];
  context: Awaited<ReturnType<typeof reviewContext>>;
  returnTo: string;
  showSalon?: boolean;
}) {
  if (!reviews.length) return <p className="empty">No reviews yet.</p>;
  return (
    <div className="review-list">
      {reviews.map((review) => {
        const author = context.accounts.get(review.author_id);
        const membership = review.employee_id
          ? context.memberships.get(review.employee_id)
          : undefined;
        const barber = membership
          ? context.accounts.get(membership.profile_id)
          : undefined;
        return (
          <article className="review-card" key={review.id}>
            <div className="row spread">
              <Identity
                name={author?.display_name ?? 'Unavailable account'}
                subtitle={`Reviewed ${date(review.created_at)}`}
                href={`/users/${review.author_id}`}
              />
              <Rating rating={review.rating} />
            </div>
            <div className="review-target">
              {showSalon && (
                <Link href={`/businesses/${review.business_id}#reviews`}>
                  {context.businesses.get(review.business_id)?.name ??
                    'View salon'}
                </Link>
              )}
              <span className="badge badge-inactive">
                {review.employee_id ? 'Barber review' : 'Salon review'}
              </span>
              {membership && (
                <Link href={`/users/${membership.profile_id}`}>
                  {barber?.display_name ?? 'View barber'}
                </Link>
              )}
            </div>
            <p className="review-body">{review.body}</p>
            <details className="moderation">
              <summary>Moderation options</summary>
              <form action={deleteReview} className="row">
                <input type="hidden" name="review" value={review.id} />
                <input type="hidden" name="returnTo" value={returnTo} />
                <p className="secondary-text">
                  Removing this review is permanent.
                </p>
                <button className="btn-danger" type="submit">
                  Remove review
                </button>
              </form>
            </details>
          </article>
        );
      })}
    </div>
  );
}

export function Pager({
  page,
  total,
  size = 25,
  href,
}: {
  page: number;
  total: number;
  size?: number;
  href: (page: number) => string;
}) {
  if (total <= size) return null;
  return (
    <nav className="pager" aria-label="Pagination">
      <span className="muted">
        Page {page + 1} of {Math.max(1, Math.ceil(total / size))}
      </span>
      <div className="row">
        {page > 0 && <Link href={href(page - 1)}>← Previous</Link>}
        {(page + 1) * size < total && <Link href={href(page + 1)}>Next →</Link>}
      </div>
    </nav>
  );
}
