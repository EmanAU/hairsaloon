'use client';
export default function ErrorPage({ reset }: { reset: () => void }) {
  return <main><section className="panel"><h1>Unable to load this page</h1><p>Please check your connection and database setup, then try again.</p><button onClick={reset}>Try again</button></section></main>;
}
