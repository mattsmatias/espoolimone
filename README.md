# Limone Bistro Espoo – hallintapaneeli

Sivusto ja hallintapaneeli samassa repossa. Hosting Vercel, tietokanta ja kirjautuminen Supabase,
lounaslistan lukeminen kuvasta tai PDF:stä Anthropicin rajapinnalla.

## Kansiorakenne

```
/index.html              sivusto (etusivu, menu, lounas)
/admin/index.html        hallintapaneeli
/api/track.js            kirjaa sivulatauksen
/api/stats.js            palauttaa tilastot paneelille
/api/parse-lunch.js      lukee lounaslistan PDF:stä tai kuvasta
/supabase-schema.sql     tietokannan rakenne
```

## 1. Supabase

1. Luo uusi projekti osoitteessa supabase.com. Nimi esimerkiksi `limone-espoo`, alue **eu-north-1 (Tukholma)**.
2. Avaa **SQL Editor**, liitä `supabase-schema.sql` kokonaisuudessaan ja aja se.
3. Avaa **Authentication → Users → Add user** ja luo tunnus Limonen henkilökunnalle
   (sähköposti + salasana, "Auto confirm user" päälle).
4. Avaa **Authentication → Providers → Email** ja laita **"Enable signups"** pois päältä,
   jotta kukaan ulkopuolinen ei voi luoda tunnusta.
5. Kopioi talteen **Settings → API**:
   - Project URL
   - anon public key
   - service_role key (tämä on salainen, vain palvelimelle)

## 2. Vercel

1. Vercel → **Add New → Project** → valitse GitHub-repo `espoolimone`.
2. Framework preset: **Other**. Root directory: repon juuri.
3. **Settings → Environment Variables**, lisää:

| Nimi | Arvo |
|---|---|
| `SUPABASE_URL` | Supabasen Project URL |
| `SUPABASE_ANON_KEY` | anon public key |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role key |
| `ANTHROPIC_API_KEY` | avain console.anthropic.com |
| `ANTHROPIC_MODEL` | `claude-sonnet-5` (valinnainen) |
| `TRACK_SALT` | mikä tahansa pitkä satunnainen merkkijono |

4. Deploy. Sivusto on osoitteessa `projekti.vercel.app`, paneeli `/admin`.
5. Lisää oma verkkotunnus kohdassa **Settings → Domains**.

## 3. Yhdistä sivusto ja paneeli tietokantaan

**`/admin/index.html`**, tiedoston lopussa oleva skripti:

```js
const SUPABASE_URL = "https://PROJEKTI.supabase.co";
const SUPABASE_ANON_KEY = "PASTE_ANON_KEY";
```

**`/index.html`**, heti `<body>`-tagin jälkeen:

```html
<script>window.LIMONE={SUPABASE_URL:"https://PROJEKTI.supabase.co",SUPABASE_ANON_KEY:"anon-key"};</script>
```

Anon key on tarkoitettu julkiseksi. Se pääsee lukemaan vain julkaistun lounaslistan ja sisältökentät,
koska tietokannan rivitason suojaus (RLS) rajaa oikeudet.

Kun kentät ovat tyhjiä, sivusto toimii normaalisti tiedostoon kirjoitetulla sisällöllä.
Se on hyvä varmistus: jos tietokanta on hetken pois käytöstä, sivu ei hajoa.

## 4. Käyttö

**Lounaslista**
- Valitse viikon maanantai, täytä annokset ja paina Tallenna ja julkaise.
- Tai raahaa Canva-PDF tai kuva tuontialueelle. Tekoäly lukee annokset, kuvaukset, hinnat ja
  L/G-merkinnät kenttiin. Tarkista tiedot ja tallenna. Mitään ei julkaista ilman tallennusta.
- Tila "Luonnos" pitää listan piilossa sivustolta.

**Sisältö**
- Yläosan tekstit, puhelin, osoite, tilauslinkki ja aukioloajat. Tallennus näkyy sivustolla heti.

**Tilastot**
- Kävijät tänään, eilen, 7 päivää ja valittu jakso, päiväkohtainen graafi,
  suosituimmat sivut ja laitejakauma.
- Ei evästeitä eikä IP-osoitteiden tallennusta: kävijä tunnistetaan päivittäin vaihtuvalla
  tiivisteellä, joka häviää vuorokauden vaihtuessa. Evästebanneria ei siis tarvita.

## Kustannukset

| Palvelu | Hinta |
|---|---|
| Vercel Hobby | 0 € |
| Supabase Free | 0 € |
| Anthropic API | noin 0,01 € per luettu lounaslista |

## Jatkokehitysideoita

- Kuvien lataus paneelista (Supabase Storage) ja vaihtaminen sivustolle
- Menun hintojen muokkaus paneelista
- Viikkolistojen historia ja kopiointi edelliseltä viikolta
- Automaattinen sähköposti-ilmoitus, jos lounaslistaa ei ole julkaistu maanantaiaamuun mennessä
- Sama paneeli monelle ravintolalle: lisää tauluihin `tenant_id` ja rajaa RLS sen mukaan
