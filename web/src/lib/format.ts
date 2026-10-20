export function date(value: string | null) {
  return value ? new Intl.DateTimeFormat('en-PK', {
    dateStyle: 'medium', timeZone: 'Asia/Karachi',
  }).format(new Date(value)) : '—';
}

export function contractStatus(row: { status: string; starts_at: string; ends_at: string | null }) {
  if (row.status !== 'accepted') return row.status;
  if (row.ends_at && new Date(row.ends_at).getTime() <= Date.now()) return 'expired';
  return new Date(row.starts_at).getTime() > Date.now() ? 'scheduled' : 'active';
}
