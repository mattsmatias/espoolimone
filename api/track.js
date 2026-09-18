// api/track.js — kirjaa sivulatauksen tietokantaan.
// Ei evasteita, ei IP-osoitteita: kavija tunnistetaan paivittain vaihtuvalla hashilla.
import { createHash } from "node:crypto";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SALT = process.env.TRACK_SALT || "limone-salt-vaihda-tama";

function device(ua = "") {
  if (/iPad|Tablet/i.test(ua)) return "tablet";
  if (/Mobi|Android|iPhone/i.test(ua)) return "mobile";
  return "desktop";
}

export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "content-type");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });

  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
    const path = String(body.path || "/").slice(0, 300);

    // Botit ohitetaan
    const ua = req.headers["user-agent"] || "";
    if (/bot|crawler|spider|preview|monitor|lighthouse/i.test(ua)) {
      return res.status(204).end();
    }

    // Paivittain vaihtuva hash: sama kavija saman paivan sisalla, ei jaljitettavissa
    const ip = (req.headers["x-forwarded-for"] || "").split(",")[0].trim();
    const today = new Date().toISOString().slice(0, 10);
    const visitor_hash = createHash("sha256").update(`${SALT}|${today}|${ip}|${ua}`).digest("hex").slice(0, 32);

    let referrer = String(body.referrer || "").slice(0, 300);
    try {
      if (referrer && new URL(referrer).hostname === req.headers.host) referrer = "";
    } catch (_) { referrer = ""; }

    const row = {
      path,
      referrer: referrer || null,
      device: device(ua),
      country: req.headers["x-vercel-ip-country"] || null,
      visitor_hash,
    };

    const r = await fetch(`${SUPABASE_URL}/rest/v1/page_views`, {
      method: "POST",
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify(row),
    });

    if (!r.ok) return res.status(500).json({ error: await r.text() });
    return res.status(204).end();
  } catch (e) {
    return res.status(500).json({ error: String(e) });
  }
}
