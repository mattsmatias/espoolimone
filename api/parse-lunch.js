// api/parse-lunch.js — lukee Canva-PDF:n tai kuvan ja palauttaa lounaslistan jasenneltyna.
// Kayttaa Anthropicin rajapintaa. Avain on vain palvelimella, ei koskaan selaimessa.
const ANTHROPIC_KEY = process.env.ANTHROPIC_API_KEY;
const MODEL = process.env.ANTHROPIC_MODEL || "claude-sonnet-5";
const SUPABASE_URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;

export const config = { api: { bodyParser: { sizeLimit: "12mb" } } };

const OHJE = `Olet ravintolan lounaslistan lukija. Saat kuvan tai PDF:n suomalaisen ravintolan viikon lounaslistasta.

Palauta VAIN JSON, ei mitaan muuta tekstia, ei koodilohkoja. Rakenne:
{
  "label": "7.9.-11.9.2026",
  "days": [
    { "weekday": 1, "items": [
        { "kind": "Pizza", "name": "Pizza Roma", "description": "salami, palvikinkku, pekoni, mozzarella", "price": 11.90, "diet": "L" }
    ]}
  ]
}

Saannot:
- weekday: 1=maanantai, 2=tiistai, 3=keskiviikko, 4=torstai, 5=perjantai.
- kind: paattele annoksesta yksi naista: Pizza, Pasta, Risotto, Insalata. Jos et ole varma, jata tyhjaksi.
- name: annoksen nimi ilman hintaa ja ilman merkintoja.
- description: raaka-aineet pienella alkukirjaimella, pilkulla eroteltuna.
- price: luku, desimaalierottimena piste. Jos hintaa ei nay, kayta null.
- diet: "L" laktoositon, "G" gluteeniton, "L G" molemmat, tyhja jos ei merkintaa.
- Ala keksi annoksia. Jos jokin paiva puuttuu listalta, jata se pois.
- Jos teksti on epaselva, kirjoita se niin kuin parhaiten luet.`;

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
  try {
    // --- vain kirjautuneille ---
    const token = (req.headers.authorization || "").replace("Bearer ", "");
    if (!token) return res.status(401).json({ error: "Kirjaudu sisaan" });
    const me = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
    });
    if (!me.ok) return res.status(401).json({ error: "Istunto vanhentunut" });

    const { data, mediaType } = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    if (!data) return res.status(400).json({ error: "Tiedosto puuttuu" });

    const block =
      mediaType === "application/pdf"
        ? { type: "document", source: { type: "base64", media_type: "application/pdf", data } }
        : { type: "image", source: { type: "base64", media_type: mediaType || "image/png", data } };

    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 4000,
        system: OHJE,
        messages: [{ role: "user", content: [block, { type: "text", text: "Lue lounaslista ja palauta JSON." }] }],
      }),
    });

    if (!r.ok) return res.status(502).json({ error: "Lukupalvelu ei vastannut: " + (await r.text()) });

    const out = await r.json();
    const text = (out.content || []).filter((c) => c.type === "text").map((c) => c.text).join("");
    const clean = text.replace(/```json|```/g, "").trim();

    let parsed;
    try {
      parsed = JSON.parse(clean);
    } catch (_) {
      const m = clean.match(/\{[\s\S]*\}/);
      if (!m) return res.status(422).json({ error: "Listaa ei saatu luettua. Kokeile terävämpää kuvaa tai PDF:aa." });
      parsed = JSON.parse(m[0]);
    }

    return res.status(200).json(parsed);
  } catch (e) {
    return res.status(500).json({ error: String(e) });
  }
}
