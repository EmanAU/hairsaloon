import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import Module, { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { transformSync } from 'next/dist/build/swc/index.js';
import { date } from '../src/lib/format.ts';

// Compile the real server component for a read-only render test. The mutation
// is stubbed so this test can never remove a review or contact the backend.
const filename = fileURLToPath(
  new URL('../src/components/admin-details.tsx', import.meta.url),
);
const require = createRequire(filename);
const compiled = transformSync(fs.readFileSync(filename, 'utf8'), {
  filename,
  jsc: {
    parser: { syntax: 'typescript', tsx: true },
    target: 'es2022',
    transform: { react: { runtime: 'automatic' } },
  },
  module: { type: 'commonjs' },
});
const componentModule = new Module(filename);
componentModule.filename = filename;
componentModule.paths = Module._nodeModulePaths(path.dirname(filename));
componentModule.require = (name) => {
  if (name === '@/lib/format') return { date };
  if (name === '@/lib/admin-types') return require('../lib/admin-types.ts');
  if (name === '@/app/actions')
    return {
      deleteReview: async () => {
        throw new Error('Mutation attempted during render');
      },
    };
  return require(name);
};
componentModule._compile(compiled.code, filename);
const { ReviewCards } = componentModule.exports;

const reviews = [
  {
    id: 'salon-review',
    author_id: 'customer-a',
    business_id: 'salon-a',
    employee_id: null,
    rating: 5,
    body: 'Excellent service',
    created_at: '2026-10-24T10:00:00Z',
  },
  {
    id: 'barber-review',
    author_id: 'customer-b',
    business_id: 'salon-b',
    employee_id: 'membership-b',
    rating: 3,
    body: '<script>untrusted review</script>',
    created_at: '2026-10-23T10:00:00Z',
  },
];
const context = {
  accounts: new Map([
    ['customer-a', { display_name: 'Customer Alpha' }],
    ['customer-b', { display_name: 'Customer Beta' }],
    ['barber-b', { display_name: 'Barber Gamma' }],
  ]),
  businesses: new Map([
    ['salon-a', { name: 'Salon Alpha' }],
    ['salon-b', { name: 'Salon Beta' }],
  ]),
  memberships: new Map([['membership-b', { profile_id: 'barber-b' }]]),
};

test('reviews show the correct author, salon and barber, with profile links', () => {
  const html = renderToStaticMarkup(
    React.createElement(ReviewCards, {
      reviews,
      context,
      returnTo: '/?view=reviews',
    }),
  );
  const cards = html.match(/<article[\s\S]*?<\/article>/g) ?? [];
  assert.equal(cards.length, 2);
  assert.match(cards[0], /Customer Alpha/);
  assert.match(cards[0], /\/users\/customer-a/);
  assert.match(cards[0], /Salon Alpha/);
  assert.doesNotMatch(cards[0], /Customer Beta|Barber Gamma/);
  assert.match(cards[1], /Customer Beta/);
  assert.match(cards[1], /Salon Beta/);
  assert.match(cards[1], /Barber Gamma/);
  assert.match(cards[1], /\/users\/barber-b/);
  assert.match(cards[1], /3 out of 5 stars/);
  assert.match(cards[1], /&lt;script&gt;/);
  assert.doesNotMatch(cards[1], /<script>/);
});

test('business page reviews retain the customer and barber when the repeated salon name is hidden', () => {
  const html = renderToStaticMarkup(
    React.createElement(ReviewCards, {
      reviews: [reviews[1]],
      context,
      returnTo: '/businesses/salon-b',
      showSalon: false,
    }),
  );
  assert.match(html, /Customer Beta/);
  assert.match(html, /Barber Gamma/);
  assert.doesNotMatch(html, /Salon Beta/);
  assert.match(html, /Removing this review is permanent/);
});

test('empty feedback has an explicit empty state', () => {
  const html = renderToStaticMarkup(
    React.createElement(ReviewCards, { reviews: [], context, returnTo: '/' }),
  );
  assert.match(html, /No reviews yet/);
  assert.doesNotMatch(html, /Remove review/);
});
