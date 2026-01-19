/**
 * GeoService (JS Unified)
 * - resolve: 座標 -> 施設名・拠点名 (Nominatim + GSI Fallback)
 * - resolveAddress: 座標 -> 住所のみ (GSI Reverse Geocoder)
 * - fetchCityTowns: 市区町村内の全町字 (Geolonia)
 * - fetchAreaTowns: 周辺の町字ノード (Overpass API)
 */
export class GeoService {
  constructor() {
    this.muniArray = null; // Pt2検索用のソート済み配列
    this.muniMap = null; // Pt1/Pt3検索用のMap
    this.reverseGeoCache = new Map();

    this.geoJsonCache = new Map();
    this.nominatimCache = new Map();
    this.MUNI_JSON_PATH = new URL(
      "./../../municipalities.json",
      import.meta.url,
    ).href;

    this.requestQueue = [];
    this.isProcessingQueue = false;
  }

  /**
   * 内部メソッド: マスタデータを一度だけロード・加工する
   */
  async _loadMuniMaster() {
    if (this.muniArray) return;

    try {
      const res = await fetch(this.MUNI_JSON_PATH);
      if (!res.ok) throw new Error("Master file load failed");
      const data = await res.json();
      const rawList = data.municipalities || [];

      // Pt2用：長い自治体名から判定するため、降順ソートして保持
      this.muniArray = [...rawList].sort(
        (a, b) =>
          (b.prefecture + b.municipality).length -
          (a.prefecture + a.municipality).length,
      );

      // Pt1/Pt3用：コード検索を O(1) にするためMapを作成
      this.muniMap = new Map(this.muniArray.map((m) => [m.muniCd5, m]));
    } catch (e) {
      console.error("GeoService: Failed to load master data.", e);
      this.muniArray = [];
      this.muniMap = new Map();
    }
  }

  /**
   * 内部メソッド: 地理院逆ジオコーダのキャッシュ付き呼び出し
   */
  async _fetchGsiReverseGeo(lat, lon) {
    const cacheKey = `${lat.toFixed(6)},${lon.toFixed(6)}`;
    if (this.reverseGeoCache.has(cacheKey))
      return this.reverseGeoCache.get(cacheKey);

    const url = `https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=${lat}&lon=${lon}`;
    try {
      const res = await fetch(url);
      const json = res.ok ? await res.json() : null;
      if (json) this.reverseGeoCache.set(cacheKey, json);
      return json;
    } catch {
      return null;
    }
  }

  // =========================================================
  // 1. Resolve: 位置情報に近くの拠点（name, desc）を割り当てる
  // =========================================================
  async resolve(point) {
    // 1. まず自治体情報を土台として付与
    await this.resolveAddress(point);

    // 2. Nominatimで詳細な拠点名(建物名など)を取りに行く
    try {
      const nominatimData = await this._fetchNominatimWithQueue(point);

      if (nominatimData && nominatimData.name) {
        // 拠点名が見つかれば name を更新
        point.name = nominatimData.name;
      } else if (!point.name && point.extensions?.municipality) {
        // 名前がなく、自治体情報がある場合は町名や市区町村名で補完
        point.name = point.extensions.town || point.extensions.municipality;
      }
    } catch (e) {
      console.warn("Nominatim failed, kept address info", e);
    }

    return point;
  }

  // =========================================================
  // 2. ResolveAddress: 位置情報に自治体情報を付与する
  // =========================================================
  async resolveAddress(point) {
    await this._loadMuniMaster();
    let muniCd5 = point.extensions?.muniCd5 || null;
    const originalTitle = point.desc || ""; // GSIの検索結果 title
    let info = null;
    let matchPattern = 0;
    let town = "";

    // --- 【Pt1】 muniCd5 から検索 ---
    if (muniCd5) {
      const cdStr = String(muniCd5).substring(0, 5).padStart(5, "0");
      info = this.muniMap.get(cdStr);
      if (info) matchPattern = 1;
    }

    // --- 【Pt2】 文字列前方一致検索 ---
    if (!info && originalTitle) {
      const cleanTitle = originalTitle.replace(/\s+/g, "");
      info = this.muniArray.find((m) =>
        cleanTitle.startsWith(
          (m.prefecture + m.municipality).replace(/\s+/g, ""),
        ),
      );
      if (info) matchPattern = 2;
    }

    // --- 【Pt3】 座標からの逆ジオコーディング ---
    if (!info && point.lat !== undefined && point.lon !== undefined) {
      const json = await this._fetchGsiReverseGeo(point.lat, point.lon);
      if (json?.results?.muniCd) {
        matchPattern = 3;
        info = this.muniMap.get(json.results.muniCd);
        town = json.results.lv01Nm || "";
      }
    }

    // --- 反映ロジック ---
    if (info) {
      if (!point.extensions) point.extensions = {};

      const resPref = info.prefecture;
      const resMuni = info.municipality;

      // 仕様に基づいた desc の決定
      if (matchPattern === 1) {
        // Pt1: マスタ(都道府県+市区町村) + GSI結果(title)
        point.desc = `${resPref}${resMuni}`;
      } else if (matchPattern === 2) {
        // Pt2: GSI結果(title) をそのまま使用
        point.desc = originalTitle;
      } else if (matchPattern === 3) {
        // Pt3: マスタ(都道府県+市区町村) + 逆ジオ結果(町字)
        point.desc = `${resPref}${resMuni}${town}`;
      }

      // 共通の拡張情報保存
      Object.assign(point.extensions, {
        muniCd5: info.muniCd5,
        prefecture: resPref,
        municipality: resMuni,
        town: town,
        matchPattern: matchPattern,
      });

      // name が未設定なら補完
      if (!point.name) {
        point.name = town ? town : resMuni;
      }
    }
    return point;
  }

  /**
   * 地名・キーワード検索を実行し、自治体情報を付与して返す
   * @param {string} query 検索キーワード
   * @returns {Promise<Array>} 検索結果リスト
   */
  /**
   * 地名・キーワード検索を実行し、自治体情報を付与して返す
   */
  async search(query) {
    if (!query || query.trim().length < 2) return [];

    await this._loadMuniMaster();

    try {
      const url = `https://msearch.gsi.go.jp/address-search/AddressSearch?q=${encodeURIComponent(
        query,
      )}`;
      const res = await fetch(url);
      if (!res.ok) throw new Error("GSI Search API error");

      const features = await res.json();

      return await Promise.all(
        features.map(async (f) => {
          const props = f.properties;
          const [lon, lat] = f.geometry.coordinates;

          // pointオブジェクトを作成（extensions内にGSIの全情報を封入）
          let point = {
            lat: lat,
            lon: lon,
            name: props.title,
            desc: props.title,
            extensions: {
              muniCd5: props.addressCode
                ? String(props.addressCode).substring(0, 5).padStart(5, "0")
                : null,
              keyword: query,
            },
          };

          // 3段階の住所解決を実行
          await this.resolveAddress(point);

          return point;
        }),
      );
    } catch (e) {
      console.error("GeoService.search failed:", e);
      return [];
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

  // =========================================================
  // 3. FetchCityTowns: 市区町村内の全町字 (Geolonia)
  // =========================================================
  async fetchCityTowns(point) {
    let target = point;
    if (!target.extensions?.prefecture || !target.extensions?.municipality) {
      target = await this.resolveAddress({ ...point }); // 元を壊さないようコピーで解決
    }

    const { prefecture, municipality } = target.extensions || {};
    if (!prefecture || !municipality) return [];

    const url = `https://geolonia.github.io/japanese-addresses/api/ja/${prefecture}/${municipality}.json`;
    try {
      const res = await fetch(url);
      if (!res.ok) return [];
      const towns = await res.json();

      return towns.map((t) => ({
        lat: Number(t.lat),
        lon: Number(t.lng),
        name: t.town,
        desc: `${prefecture}${municipality}${t.town}`,
        extensions: {
          ...target.extensions,
          town: t.town,
        },
      }));
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
          .map((el) => ({
            lat: Number(el.lat),
            lon: Number(el.lon),
            name: el.tags.name,
            desc: "Overpass Place",
            extensions: {},
          }));
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
            setTimeout(
              () => {
                this.requestQueue.unshift({
                  point,
                  retryCount: retryCount + 1,
                  resolve,
                  reject,
                });
                this._processQueue();
              },
              2000 * (retryCount + 1),
            );
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
}

export const geoService = new GeoService();
