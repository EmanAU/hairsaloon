import test from 'node:test';
import assert from 'node:assert/strict';
import { participation, businessStatus } from '../src/lib/admin-types.ts';

const now = Date.parse('2026-10-24T10:00:00Z');
const user = { id: 'person', role: 'user' };
const active = {
  profile_id: 'person',
  status: 'accepted',
  starts_at: '2026-10-01T00:00:00Z',
  ends_at: null,
};

test('ownership, employment and customer activity can coexist without granting admin access', () => {
  assert.deepEqual(
    participation(
      user,
      [{ owner_id: 'person' }],
      [active],
      [{ author_id: 'person' }],
      now,
    ),
    ['Owner', 'Employee', 'Customer'],
  );
  assert.deepEqual(
    participation({ ...user, role: 'superadmin' }, [], [], [], now),
    ['Superadmin'],
  );
});

test('pending, declined, released, scheduled and expired agreements do not label someone as working', () => {
  for (const contract of [
    { ...active, status: 'draft' },
    { ...active, status: 'declined' },
    { ...active, status: 'released' },
    { ...active, starts_at: '2026-11-01T00:00:00Z' },
    { ...active, ends_at: '2026-10-24T10:00:00Z' },
  ])
    assert.deepEqual(participation(user, [], [contract], [], now), [
      'Registered user',
    ]);
});

test('another account’s business, contract or review does not change this account’s labels', () => {
  assert.deepEqual(
    participation(
      user,
      [{ owner_id: 'other' }],
      [{ ...active, profile_id: 'other' }],
      [{ author_id: 'other' }],
      now,
    ),
    ['Registered user'],
  );
});

test('unreviewed and previously deactivated businesses have distinct statuses', () => {
  assert.equal(
    businessStatus({ is_active: false, reviewed_at: null }),
    'Pending approval',
  );
  assert.equal(
    businessStatus({ is_active: false, reviewed_at: '2026-10-01' }),
    'Inactive',
  );
  assert.equal(
    businessStatus({ is_active: true, reviewed_at: '2026-10-01' }),
    'Active',
  );
});
