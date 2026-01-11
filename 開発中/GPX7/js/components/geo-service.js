/**
 * 自治体・地理情報解決サービス
 */
class GeoService {
  constructor() {
    this.muniCache = null;
    this.geoJsonCache = new Map();
    this.addressCache = new Map();
    this.MUNI_JSON_PATH = new URL(
      "./../../municipalities.json",
      import.meta.url
    ).href;

    this.requestQueue = [];
    this.isProcessingQueue = false;
  }

  /**
   * 内部用：新しいPointオブジェクトの生成
   */
  _createPoint(lat, lon, name = "", desc = "", extData = null) {
    const point = { lat, lon, name, desc };

    // extDataが extensions プロパティそのものか、マスタの1行かどちらでも対応
    const data = extData?.muniCd5 ? extData : null;

    if (data) {
      point.extensions = {
        municipality: data.municipality || "",
        muniCd6: data.muniCd6 || "",
        prefecture: data.prefecture || "",
        prefecture_code: data.prefecture_code || "",
        muniCd5: data.muniCd5 || "",
      };
    }
    return point;
  }

  // --- 1. resolve: lat,lon から自治体情報を解決 ---
  async resolve(point) {
    const { lat, lon } = point;
    const url = `https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=${lat}&lon=${lon}`;

    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error("GSI Request failed");
      const json = await res.json();

      if (!json.results?.muniCd) return point;

      const muniCd5 = json.results.muniCd;
      const townName = json.results.lv01Nm || ""; // ★ GSIから返ってくる町名を取得

      const master = await this._loadMuniMaster();
      const info = master.municipalities.find((m) => m.muniCd5 === muniCd5);

      if (!info) return point;

      // nameを lv01Nm に、descを 都道府県+市区町村 に設定
      // もし lv01Nm が空なら市区町村名を name にする
      return this._createPoint(
        lat,
        lon,
        townName || info.municipality,
        `${info.prefecture}${info.municipality}`,
        info
      );
    } catch (e) {
      console.error("Resolve failed", e);
      return point;
    }
  }

  async resolveAddress(point, retryCount = 0) {
    const cacheKey = `${point.lat}_${point.lon}`;
    if (this.addressCache.has(cacheKey)) return this.addressCache.get(cacheKey);

    return new Promise((resolve, reject) => {
      this.requestQueue.push({ point, retryCount, resolve, reject });
      this._processQueue();
    });
  }
  async _processQueue() {
    if (this.isProcessingQueue || this.requestQueue.length === 0) return;
    this.isProcessingQueue = true;

    try {
      while (this.requestQueue.length > 0) {
        const { point, retryCount, resolve, reject } =
          this.requestQueue.shift();

        // OSMレート制限対策 (1秒待機)
        await new Promise((r) => setTimeout(r, 1000));

        const cacheKey = `${point.lat}_${point.lon}`;
        if (this.addressCache.has(cacheKey)) {
          resolve(this.addressCache.get(cacheKey));
          continue;
        }

        const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.lat}&lon=${point.lon}&zoom=18&addressdetails=1`;

        try {
          const res = await fetch(url, {
            headers: { "User-Agent": "MyMapApp/1.0 (contact@example.com)" },
          });
          if (!res.ok) throw new Error(`HTTP error ${res.status}`);

          const data = await res.json();
          this.addressCache.set(cacheKey, data);
          resolve(data);
        } catch (e) {
          if (retryCount < 3) {
            const delay = 1000 * Math.pow(2, retryCount);
            setTimeout(() => {
              this.requestQueue.unshift({
                point,
                retryCount: retryCount + 1,
                resolve,
                reject,
              });
              this._processQueue();
            }, delay);
          } else {
            reject(e);
          }
        }
      }
    } finally {
      this.isProcessingQueue = false;
    }
  }

  // --- 2. fetchBoundary: 自治体境界の取得 ---
  async fetchBoundary(point) {
    let target = point;
    if (!target.extensions?.muniCd5) {
      target = await this.resolve(point);
    }

    const { muniCd5 } = target.extensions || {};
    if (!muniCd5) return null;

    if (this.geoJsonCache.has(muniCd5)) return this.geoJsonCache.get(muniCd5);

    const url = `https://shikuchoson-boundaries.sankichi.app/${muniCd5}.geojson`;
    try {
      const res = await fetch(url);
      if (!res.ok) return null;
      const geoJson = await res.json();
      this.geoJsonCache.set(muniCd5, geoJson);
      return geoJson;
    } catch {
      return null;
    }
  }

  // --- 3. fetchCityTowns: 市区町村内の全町字を取得 ---
  async fetchCityTowns(point) {
    let target = point;
    if (!target.extensions?.prefecture || !target.extensions?.municipality) {
      target = await this.resolve(point);
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
          target.extensions
        )
      );
    } catch {
      return [];
    }
  }

  // --- 4. fetchAreaTowns: リトライ機能付き (node限定) ---
  async fetchAreaTowns(point, radius = 1000, retries = 3) {
    const { lat, lon } = point;
    const r = Math.floor(radius);
    // 町字のポイント(node)のみに絞ったクエリ
    const query = `[out:json][timeout:60];node["place"~"^(neighbourhood|quarter|locality)$"](around:${r},${lat},${lon});out body;`;
    const url = `https://overpass-api.de/api/interpreter?data=${encodeURIComponent(
      query
    )}`;

    for (let i = 0; i <= retries; i++) {
      try {
        const res = await fetch(url);
        if (res.status === 429 || res.status >= 500)
          throw new Error(`Server Error: ${res.status}`);
        if (!res.ok) break;

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
        if (i === retries) break;
        const delay = Math.pow(2, i) * 1000;
        console.warn(`Retry ${i + 1}/${retries} after ${delay}ms...`);
        await new Promise((r) => setTimeout(r, delay));
      }
    }
    return [];
  }

  async _loadMuniMaster() {
    if (this.muniCache) return this.muniCache;
    try {
      const res = await fetch(this.MUNI_JSON_PATH);
      if (!res.ok) throw new Error("MuniMaster load failed");
      this.muniCache = await res.json();
      return this.muniCache;
    } catch (e) {
      console.error(e);
      return { municipalities: [] };
    }
  }
}

export const geoService = new GeoService();
