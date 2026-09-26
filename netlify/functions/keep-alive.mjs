// Free Supabase projects pause after a week without activity. This Netlify
// scheduled function (free) makes one tiny read every day to keep the
// Rent AL database awake. It reads the public car categories only.
const SUPABASE_URL = 'https://cihhvvhhkgqgqbuwhjwh.supabase.co';
const SUPABASE_KEY = 'sb_publishable_Qw0bDFw4P7qWh-8yZkVtOQ_ECT7UH7Z';

export default async () => {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/car_categories?select=id&limit=1`, {
    headers: { apikey: SUPABASE_KEY },
  });
  console.log(`keep-alive: Supabase answered ${res.status}`);
  return new Response(null, { status: res.ok ? 200 : 502 });
};

export const config = { schedule: '@daily' };
