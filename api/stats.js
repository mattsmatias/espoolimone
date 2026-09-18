// api/stats.js — palauttaa kavijatilastot hallintapaneelille.
// Vaatii kirjautuneen kayttajan (Supabase-token Authorization-otsikossa).
const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;

async function db(pathAndQuery) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${pathAndQuery}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

export default async function handler(req, res) {
  try {
    // --- tarkista kirjautuminen ---
    const token = (req.headers.authorization || "").replace("Bearer ", "");
    if (!token) return res.status(401).json({ error: "Kirjaudu sisaan" });

    const me = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
    });
    if (!me.ok) return res.status(401).json({ error: "Istunto vanhentunut" });

    // --- hae tilastot ---
    const days = Math.min(parseInt(req.query.days || "30", 10) || 30, 180);
    const since = new Date(Date.now() - days * 864e5).toISOString().slice(0, 10);

    const [daily, pages, devices] = await Promise.all([
      db(`stats_daily?day=gte.${since}&select=*&order=day.asc`),
      db(`stats_pages?select=*&limit=20`),
      db(`stats_devices?select=*`),
    ]);

    const today = new Date().toISOString().slice(0, 10);
    const yday = new Date(Date.now() - 864e5).toISOString().slice(0, 10);
    const sum = (arr, k) => arr.reduce((a, b) => a + Number(b[k] || 0), 0);
    const last7 = daily.slice(-7);
    const prev7 = daily.slice(-14, -7);

    res.setHeader("Cache-Control", "no-store");
    return res.status(200).json({
      daily,
      pages,
      devices,
      summary: {
        today: daily.find((d) => d.day === today) || { views: 0, visitors: 0 },
        yesterday: daily.find((d) => d.day === yday) || { views: 0, visitors: 0 },
        week_views: sum(last7, "views"),
        week_visitors: sum(last7, "visitors"),
        prev_week_views: sum(prev7, "views"),
        period_views: sum(daily, "views"),
        period_visitors: sum(daily, "visitors"),
      },
    });
  } catch (e) {
    return res.status(500).json({ error: String(e) });
  }
}
