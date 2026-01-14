/**
 * GeoService (JS Unified)
 * - resolve: 座標 -> 施設名・拠点名 (Nominatim + GSI Fallback)
 * - resolveAddress: 座標 -> 住所のみ (GSI Reverse Geocoder)
 * - fetchCityTowns: 市区町村内の全町字 (Geolonia)
 * - fetchAreaTowns: 周辺の町字ノード (Overpass API)
 */
export class GeoService {
  constructor() {
    this.muniCache = null;
    this.geoJsonCache = new Map();
    this.nominatimCache = new Map();
    this.MUNI_JSON_PATH = new URL(
      "./../../municipalities.json",
      import.meta.url
    ).href;

    // Queue for Nominatim (limit 1 req/sec)
    this.requestQueue = [];
    this.isProcessingQueue = false;
  }

  /**
   * 内部用：Pointオブジェクトの生成
   */
  _createPoint(lat, lon, name = "", desc = "", extData = null) {
    const exts = extData || {};
    return {
      lat: Number(lat),
      lon: Number(lon),
      name: name || "",
      desc: desc || "",
      extensions: {
        muniCd5: exts.muniCd5 || "",
        municipality: exts.municipality || "",
        prefecture: exts.prefecture || "",
        town: exts.town || exts.block || "",
      },
    };
  }

  // =========================================================
  // 1. Resolve: 座標 -> 施設名/詳細住所 (Nominatim優先 + GSI)
  // =========================================================
  async resolve(point) {
    // ベースとなる住所情報を取得
    let basePoint = await this.resolveAddress(point);

    // Nominatimで詳細な場所名(建物名など)を取りに行く
    try {
      const nominatimData = await this._fetchNominatimWithQueue(point);

      // Nominatimの結果から名前が取れれば採用
      if (nominatimData && nominatimData.name) {
        return this._createPoint(
          point.lat,
          point.lon,
          nominatimData.name, // Name: 施設名
          basePoint.desc, // Desc: 正確な住所(GSI)
          basePoint.extensions // Extensions: 住所情報
        );
      }
    } catch (e) {
      console.warn("Nominatim failed, falling back to address", e);
    }

    // 失敗時は住所情報のみを返す
    return basePoint;
  }

  // =========================================================
  // 2. ResolveAddress: 座標 -> 住所のみ (GSI Reverse Geocoder)
  // =========================================================
  async resolveAddress(point) {
    const { lat, lon } = point;
    const url = `https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=${lat}&lon=${lon}`;

    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error("GSI Request failed");
      const json = await res.json();

      if (!json.results?.muniCd) return point;

      const muniCd5 = json.results.muniCd;
      const townName = json.results.lv01Nm || "";

      const master = await this._loadMuniMaster();
      const info = master.municipalities.find((m) => m.muniCd5 === muniCd5);

      if (!info) return point;

      const extData = { ...info, town: townName };

      // Name: 町名(なければ市区町村名), Desc: フル住所
      return this._createPoint(
        lat,
        lon,
        townName || info.municipality,
        `${info.prefecture}${info.municipality}${townName}`,
        extData
      );
    } catch (e) {
      console.warn("GSI Resolve failed", e);
      return point;
    }
  }

  // =========================================================
  // 3. FetchCityTowns: 市区町村内の全町字 (Geolonia)
  // =========================================================
  async fetchCityTowns(point) {
    let target = point;
    // 必要な情報がなければまずResolveAddressする
    if (!target.extensions?.prefecture || !target.extensions?.municipality) {
      target = await this.resolveAddress(point);
    }

    const { prefecture, municipality } = target.extensions || {};
    if (!prefecture || !municipality) return [];

    const url = `https://geolonia.github.io/japanese-addresses/api/ja/${prefecture}/${municipality}.json`;
    try {
      const res = await fetch(url);
      if (!res.ok) return [];
      const towns = await res.json();

      return towns.map((t) =>
        this._createPoint(
          t.lat,
          t.lng,
          t.town,
          `${prefecture}${municipality}${t.town}`,
          { ...target.extensions, town: t.town }
        )
      );
    } catch {
      return [];
    }
  }

  // =========================================================
  // 4. FetchAreaTowns: 周辺の町字ノード (Overpass API)
  // =========================================================
  async fetchAreaTowns(point, radius = 1000) {
    const { lat, lon } = point;
    const r = Math.floor(radius);
    // place=neighbourhood, quarter, locality などを検索
    const query = `[out:json][timeout:30];node["place"~"^(neighbourhood|quarter|locality)$"](around:${r},${lat},${lon});out body;`;
    const url = "https://overpass-api.de/api/interpreter";

    for (let i = 0; i < 3; i++) {
      try {
        const body = "data=" + encodeURIComponent(query);
        const res = await fetch(url, { method: "POST", body });

        if (!res.ok) {
          if (res.status === 429) {
            await new Promise((r) => setTimeout(r, 5000));
            continue;
          }
          throw new Error(res.statusText);
        }

        const json = await res.json();
        return json.elements
          .filter((el) => el.tags?.name)
          .map((el) =>
            this._createPoint(
              el.lat,
              el.lon,
              el.tags.name,
              "Overpass Place",
              null
            )
          );
      } catch (e) {
        console.warn(`Overpass retry ${i + 1}`, e);
        await new Promise((r) => setTimeout(r, 2000 * (i + 1)));
      }
    }
    return [];
  }

  // --- Internal: Nominatim Queue Processing ---
  async _fetchNominatimWithQueue(point) {
    const cacheKey = `${point.lat}_${point.lon}`;
    if (this.nominatimCache.has(cacheKey))
      return this.nominatimCache.get(cacheKey);

    return new Promise((resolve, reject) => {
      this.requestQueue.push({ point, retryCount: 0, resolve, reject });
      this._processQueue();
    });
  }

  async _processQueue() {
    if (this.isProcessingQueue || this.requestQueue.length === 0) return;
    this.isProcessingQueue = true;

    try {
      while (this.requestQueue.length > 0) {
        const item = this.requestQueue[0];
        const { point, retryCount, resolve, reject } = item;
        const cacheKey = `${point.lat}_${point.lon}`;

        if (this.nominatimCache.has(cacheKey)) {
          this.requestQueue.shift();
          resolve(this.nominatimCache.get(cacheKey));
          continue;
        }

        // Wait 1.1s (Nominatim Policy)
        await new Promise((r) => setTimeout(r, 1100));
        this.requestQueue.shift();

        const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.lat}&lon=${point.lon}&zoom=18&addressdetails=1`;
        try {
          const res = await fetch(url, {
            headers: { "User-Agent": "MyMapApp/1.0" },
          });
          if (!res.ok) throw new Error(`HTTP error ${res.status}`);
          const data = await res.json();
          this.nominatimCache.set(cacheKey, data);
          resolve(data);
        } catch (e) {
          if (retryCount < 3) {
            setTimeout(() => {
              this.requestQueue.unshift({
                point,
                retryCount: retryCount + 1,
                resolve,
                reject,
              });
              this._processQueue();
            }, 2000 * (retryCount + 1));
            return;
          } else {
            reject(e);
          }
        }
      }
    } finally {
      this.isProcessingQueue = false;
      if (this.requestQueue.length > 0) this._processQueue();
    }
  }

  // --- Internal: Load Master Data ---
  async _loadMuniMaster() {
    if (this.muniCache) return this.muniCache;
    try {
      const res = await fetch(this.MUNI_JSON_PATH);
      if (!res.ok) throw new Error("Failed");
      this.muniCache = await res.json();
      return this.muniCache;
    } catch {
      return { municipalities: [] };
    }
  }
}

export const geoService = new GeoService();
