// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };

type ComputeEtaPayload = {
  vozac_id?: string;
  lat?: number;
  lng?: number;
  grad?: string;
  vreme?: string;
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function coordStr(lat: number, lng: number): string {
  return `${lng},${lat}`;
}

function normalizeDate(value: unknown): string {
  return String(value ?? "").trim().split("T")[0];
}

function normalizeTime(value: unknown): string {
  const raw = String(value ?? "").trim();
  if (!raw) return "";
  const timePart = raw.includes("T") ? raw.split("T")[1] : raw;
  return timePart.slice(0, 8);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json(200, { ok: false, reason: "method_not_allowed" });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
    const osrmBaseUrl =
      Deno.env.get("OSRM_BASE_URL")?.trim() || "https://router.project-osrm.org";

    if (!supabaseUrl || !serviceRoleKey) {
      return json(200, { ok: false, reason: "missing_supabase_credentials" });
    }

    const payload = (await req.json()) as ComputeEtaPayload;
    const vozacId = String(payload.vozac_id ?? "").trim();
    const driverLat = Number(payload.lat);
    const driverLng = Number(payload.lng);
    const activeGrad = String(payload.grad ?? "").trim().toUpperCase();
    const activeVreme = normalizeTime(payload.vreme);

    if (!vozacId || !Number.isFinite(driverLat) || !Number.isFinite(driverLng)) {
      return json(200, { ok: false, reason: "invalid_payload" });
    }
    if (!activeGrad || !activeVreme) {
      return json(200, { ok: false, reason: "missing_grad_vreme" });
    }

    const client = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 0. Obriši globalno sve zastarele ETA redove (starije od 90 sekundi)
    const staleThreshold = new Date(Date.now() - 90_000).toISOString();
    await client.from("v3_eta_results").delete().lt("computed_at", staleThreshold);

    // 1. Pronađi aktivne dodele (putnik_id + termin_id) - koristimo termin-level dodele
    const { data: dodelaRows, error: dodelaError } = await client
      .from("v3_trenutna_dodela")
      .select("putnik_v3_auth_id, termin_id")
      .eq("vozac_v3_auth_id", vozacId)
      .eq("status", "aktivan");

    if (dodelaError) {
      return json(200, { ok: false, reason: "dodela_lookup_error", warning: dodelaError.message });
    }

    if (!dodelaRows || dodelaRows.length === 0) {
      await client.from("v3_eta_results").delete().eq("vozac_id", vozacId);
      return json(200, { ok: true, reason: "no_active_dodele", updated: 0 });
    }

    const allTerminIds = dodelaRows.map((r) => String(r.termin_id ?? "").trim()).filter(Boolean);

    // 2. Dohvati termin podatke direktno po termin_id (tačan red, bez mešanja termina)
    const { data: operativnaRows, error: operativnaError } = await client
      .from("v3_operativna_nedelja")
      .select("id, created_by, datum, grad, polazak_at, pokupljen_at, otkazano_at, adresa_override_id, koristi_sekundarnu")
      .in("id", allTerminIds);

    if (operativnaError) {
      console.warn(`[v3-compute-eta] operativna lookup error: ${operativnaError.message}`);
    }

    // Mapa termin_id → operativna red (samo za aktivni grad+vreme)
    const terminMap: Record<string, {
      putnikId: string;
      pokupljenAt: string | null;
      otkazanoAt: string | null;
      adresaOverrideId: string | null;
      koristiSekundarnu: boolean;
      grad: string;
      vreme: string;
    }> = {};
    for (const row of (operativnaRows ?? [])) {
      const terminId = String(row.id ?? "").trim();
      if (!terminId) continue;

      const rowGrad = String(row.grad ?? "").trim().toUpperCase();
      const rowVreme = normalizeTime(row.polazak_at);

      // Filtriraj samo aktivni termin
      if (rowGrad !== activeGrad || rowVreme !== activeVreme) continue;

      terminMap[terminId] = {
        putnikId: String(row.created_by ?? "").trim(),
        pokupljenAt: row.pokupljen_at ?? null,
        otkazanoAt: row.otkazano_at ?? null,
        adresaOverrideId: row.adresa_override_id ? String(row.adresa_override_id) : null,
        koristiSekundarnu: row.koristi_sekundarnu === true,
        grad: rowGrad,
        vreme: rowVreme,
      };
    }

    const adresaOverrideMap: Record<string, string> = {};   // putnikId → adresa_override_id
    const koristiSekundarnaMap: Record<string, boolean> = {}; // putnikId → koristi_sekundarnu

    // 3. Preostali putnici — nisu pokupljeni NI otkazani
    const remainingDodele = dodelaRows.filter((r) => {
      const terminId = String(r.termin_id ?? "").trim();
      const termin = terminMap[terminId];
      if (!termin) return false;
      return !termin.pokupljenAt && !termin.otkazanoAt;
    });

    // Popuni adresaOverrideMap i koristiSekundarnaMap za preostale
    for (const r of remainingDodele) {
      const terminId = String(r.termin_id ?? "").trim();
      const termin = terminMap[terminId];
      if (!termin) continue;
      const pid = termin.putnikId;
      if (!pid) continue;
      if (termin.adresaOverrideId) adresaOverrideMap[pid] = termin.adresaOverrideId;
      koristiSekundarnaMap[pid] = termin.koristiSekundarnu;
    }

    if (remainingDodele.length === 0) {
      return json(200, { ok: true, reason: "no_remaining_dodele", updated: 0 });
    }

    // Odredi grad iz prvog preostalog termina
    const firstTerminId = String(remainingDodele[0]?.termin_id ?? "").trim();
    const firstTermin = terminMap[firstTerminId];
    const gradNorm = firstTermin?.grad ?? "BC"; // Fallback to BC if not found

    const remainingPutnikIds = remainingDodele
      .map((r) => terminMap[String(r.termin_id ?? "").trim()]?.putnikId ?? String(r.putnik_v3_auth_id ?? "").trim())
      .filter(Boolean);

    // Obriši ETA za putnike koji nisu u aktivnom terminu (druga smena)
    const activePutnikIds = new Set<string>(remainingPutnikIds);
    const { data: existingEtaRows } = await client
      .from("v3_eta_results")
      .select("putnik_id")
      .eq("vozac_id", vozacId);
    const putniciZaBrisanje = (existingEtaRows ?? [])
      .map((r: any) => String(r.putnik_id ?? "").trim())
      .filter((pid: string) => pid && !activePutnikIds.has(pid));
    if (putniciZaBrisanje.length > 0) {
      await client.from("v3_eta_results").delete()
        .eq("vozac_id", vozacId)
        .in("putnik_id", putniciZaBrisanje);
    }

    // 4. Dohvati profile putnika (adresa_bc_id, adresa_vs_id itd.)
    const { data: authRows, error: authError } = await client
      .from("v3_auth")
      .select("id, adresa_primary_bc_id, adresa_primary_vs_id, adresa_secondary_bc_id, adresa_secondary_vs_id")
      .in("id", remainingPutnikIds);

    if (authError) {
      return json(200, { ok: false, reason: "auth_lookup_error", warning: authError.message });
    }

    const authMap: Record<string, { adresa_primary_bc_id?: string; adresa_primary_vs_id?: string; adresa_secondary_bc_id?: string; adresa_secondary_vs_id?: string }> = {};
    for (const row of (authRows ?? [])) {
      authMap[String(row.id)] = row;
    }

    // 5. Odredi adresa_id za svakog preostalog putnika na osnovu grad + koristi_sekundarnu + override
    const adresaIds = new Set<string>();
    const putnikAdresaIdMap: Record<string, string> = {}; // putnikId → adresaId

    for (const pid of remainingPutnikIds) {
      const override = adresaOverrideMap[pid];
      if (override) {
        putnikAdresaIdMap[pid] = override;
        adresaIds.add(override);
        continue;
      }
      const auth = authMap[pid];
      if (!auth) continue;
      const koristiSek = koristiSekundarnaMap[pid] === true;
      let adresaId: string | undefined;
      if (gradNorm === "BC") {
        adresaId = koristiSek ? auth.adresa_secondary_bc_id : auth.adresa_primary_bc_id;
      } else {
        adresaId = koristiSek ? auth.adresa_secondary_vs_id : auth.adresa_primary_vs_id;
      }
      if (adresaId) {
        putnikAdresaIdMap[pid] = String(adresaId);
        adresaIds.add(String(adresaId));
      }
    }

    // 7. Dohvati koordinate adresa iz v3_adrese (gps_lat / gps_lng)
    const adresaCoordMap: Record<string, { lat: number; lng: number }> = {};

    if (adresaIds.size > 0) {
      const { data: adreseRows, error: adreseError } = await client
        .from("v3_adrese")
        .select("id, gps_lat, gps_lng")
        .in("id", Array.from(adresaIds));

      if (adreseError) {
        console.warn(`[v3-compute-eta] adrese lookup error: ${adreseError.message}`);
      }

      for (const row of (adreseRows ?? [])) {
        const lat = Number(row.gps_lat);
        const lng = Number(row.gps_lng);
        if (Number.isFinite(lat) && Number.isFinite(lng)) {
          adresaCoordMap[String(row.id)] = { lat, lng };
        }
      }
    }

    // 8. Gradi listu preostalih waypointa sa koordinatama iz adresa
    type WpEntry = { putnikId: string; lat: number; lng: number };
    const remainingWaypoints: WpEntry[] = [];

    for (const pid of remainingPutnikIds) {
      const adresaId = putnikAdresaIdMap[pid];
      const fromAdresa = adresaId ? adresaCoordMap[adresaId] : undefined;
      const coord = fromAdresa;
      if (!coord) {
        console.warn(`[v3-compute-eta] putnik ${pid} nema koordinate — preskačem`);
        continue;
      }
      remainingWaypoints.push({ putnikId: pid, lat: coord.lat, lng: coord.lng });
    }

    if (remainingWaypoints.length === 0) {
      return json(200, { ok: true, reason: "no_coords_for_remaining", updated: 0 });
    }

    // 9. OSRM /trip: vozač (source=first) → preostali putnici → suprotni grad (destination=last)
    // Odredi koordinate suprotnog grada
    const destLat = gradNorm === "BC" ? 45.1196 : 44.8994; // BC -> Vršac, VS -> Bela Crkva
    const destLng = gradNorm === "BC" ? 21.3050 : 21.4165;

    const tripCoords = [
      coordStr(driverLat, driverLng),
      ...remainingWaypoints.map((w) => coordStr(w.lat, w.lng)),
      coordStr(destLat, destLng)
    ].join(";");

    const osrmUrl =
      `${osrmBaseUrl}/trip/v1/driving/${tripCoords}` +
      `?source=first&destination=last&roundtrip=false&steps=false&overview=false`;

    let osrmResponse: Response;
    try {
      osrmResponse = await fetch(osrmUrl, { signal: AbortSignal.timeout(12000) });
    } catch (e) {
      await new Promise((resolve) => setTimeout(resolve, 2000));
      osrmResponse = await fetch(osrmUrl, { signal: AbortSignal.timeout(12000) });
    }

    if (!osrmResponse.ok) {
      return json(200, { ok: false, reason: "osrm_http_error", status: osrmResponse.status });
    }

    const osrmData = await osrmResponse.json();
    if (osrmData.code !== "Ok") {
      return json(200, { ok: false, reason: "osrm_code_error", code: osrmData.code });
    }

    // 10. Parsiraj optimizovani redosled iz waypoints[].waypoint_index
    // OSRM /trip vraća waypoints u trip-redosledu (optimizovanom).
    // Svaki waypoint ima waypoint_index = originalni redni broj u zahtevu.
    // Indeks 0 je vozač (source=first), poslednji je destinacioni grad.
    const rawWaypoints = osrmData.waypoints;
    const rawTrips = osrmData.trips;

    if (!Array.isArray(rawWaypoints) || rawWaypoints.length !== tripCoords.split(";").length) {
      return json(200, { ok: false, reason: "osrm_waypoints_mismatch" });
    }
    if (!Array.isArray(rawTrips) || rawTrips.length === 0) {
      return json(200, { ok: false, reason: "osrm_no_trips" });
    }

    const legs = rawTrips[0].legs;
    if (!Array.isArray(legs)) {
      return json(200, { ok: false, reason: "osrm_no_legs" });
    }

    // Putnički waypoints su već u optimalnom trip-redosledu nakon slice(1, -1)
    const passengerWaypoints = rawWaypoints.slice(1, -1);

    // 11. Izračunaj kumulativni ETA u optimalnom redosledu
    // legs[0] = vozač → prvi putnik u trip-u, legs[1] = prvi → drugi, itd.
    const now = new Date().toISOString();
    const upsertRows: Array<{
      putnik_id: string;
      vozac_id: string;
      eta_seconds: number;
      computed_at: string;
    }> = [];

    let cumulative = 0;
    for (let tripRank = 0; tripRank < passengerWaypoints.length; tripRank++) {
      const leg = legs[tripRank];
      const duration = Number(leg?.duration ?? -1);
      if (!Number.isFinite(duration) || duration < 0) {
        console.warn(`[v3-compute-eta] leg[${tripRank}] duration invalid: ${duration}`);
        continue;
      }
      cumulative += Math.round(duration);

      const originalIdx = Number(passengerWaypoints[tripRank].waypoint_index ?? tripRank + 1) - 1; // -1 jer je vozač index 0
      const putnikId = remainingWaypoints[originalIdx]?.putnikId;
      if (!putnikId) continue;

      upsertRows.push({
        putnik_id: putnikId,
        vozac_id: vozacId,
        eta_seconds: cumulative,
        computed_at: now,
      });
    }

    if (upsertRows.length === 0) {
      return json(200, { ok: true, reason: "no_eta_rows", updated: 0 });
    }

    // 12. UPSERT u v3_eta_results
    const { error: upsertError } = await client
      .from("v3_eta_results")
      .upsert(upsertRows, { onConflict: "putnik_id,vozac_id" });

    if (upsertError) {
      return json(200, { ok: false, reason: "upsert_error", warning: upsertError.message });
    }

    console.log(`[v3-compute-eta] ✅ vozac=${vozacId.substring(0, 8)} updated=${upsertRows.length} putnika`);

    return json(200, { ok: true, updated: upsertRows.length });
  } catch (error) {
    return json(200, {
      ok: false,
      reason: "unexpected_error",
      warning: error instanceof Error ? error.message : "Unknown error",
    });
  }
});
