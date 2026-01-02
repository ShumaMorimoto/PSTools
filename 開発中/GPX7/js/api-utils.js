// api-utils.js (最終統合版)

const addressCache = new Map(); // キャッシュ

// シリアルキュー
const requestQueue = [];
let isProcessingQueue = false;

// api-utils.js

let muniCache = null;

// municipalities.json を内部キャッシュでロード
async function loadMunicipalitiesInternal() {
  if (muniCache) return muniCache;

  const res = await fetch("./../municipalities.json");
  muniCache = await res.json();
  return muniCache;
}

// ----------------------------------------
// ★ 座標 → muniInfo（最終形）
// ----------------------------------------
export async function fetchMuniInfo(lat, lng) {
  // 1. GSI 逆ジオで muniCd5 を取得
  const url = `https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=${lat}&lon=${lng}`;
  let muniCd5 = null;

  try {
    const res = await fetch(url);
    const json = await res.json();
    muniCd5 = json.results.muniCd;
  } catch {
    return null;
  }

  // 2. municipalities.json をロードして muniInfo を返す
  const muniData = await loadMunicipalitiesInternal();
  return muniData.municipalities.find((m) => m.muniCd5 === muniCd5) || null;
}

// ----------------------------------------
// 自治体境界 GeoJSON
// ----------------------------------------
export async function fetchBoundary(muniInfo) {
  const url = `https://shikuchoson-boundaries.sankichi.app/${muniInfo.muniCd5}.geojson`;
  try {
    const res = await fetch(url);
    return await res.json();
  } catch {
    return null;
  }
}

// ----------------------------------------
// 町字データ
// ----------------------------------------
export async function fetchTowns(muniInfo) {
  const pref = muniInfo.prefecture;
  const muni = muniInfo.municipality;
  const url = `https://geolonia.github.io/japanese-addresses/api/ja/${pref}/${muni}.json`;

  try {
    const res = await fetch(url);
    return await res.json();
  } catch {
    return [];
  }
}

// ----------------------------------------
// 住所取得（逆ジオ）
// ----------------------------------------
export async function fetchAddressAsync(point, retryCount = 0) {
  const cacheKey = `${point.lat}_${point.lon}`;

  // キャッシュヒット
  if (addressCache.has(cacheKey)) {
    return addressCache.get(cacheKey);
  }

  return new Promise((resolve, reject) => {
    requestQueue.push({
      point,
      retryCount,
      resolve,
      reject,
    });
    processQueue();
  });
}

async function processQueue() {
  if (isProcessingQueue || requestQueue.length === 0) return;
  isProcessingQueue = true;

  try {
    while (requestQueue.length > 0) {
      const { point, retryCount, resolve, reject } = requestQueue.shift();

      // レート制限対策
      await new Promise((r) => setTimeout(r, 1000));
      const cacheKey = `${point.lat}_${point.lon}`;

      // キャッシュ再確認
      if (addressCache.has(cacheKey)) {
        resolve(addressCache.get(cacheKey));
        continue;
      }

      const url =
        `https://nominatim.openstreetmap.org/reverse?format=json` +
        `&lat=${point.lat}&lon=${point.lon}&zoom=18&addressdetails=1`;

      try {
        const res = await fetch(url, {
          headers: { "User-Agent": "MyMapApp/1.0 (contact@example.com)" },
        });

        if (!res.ok) throw new Error(`HTTP error ${res.status}`);

        const data = await res.json();
        addressCache.set(cacheKey, data);

        resolve(data);
      } catch (e) {
        if (retryCount < 3) {
          const delay = 1000 * Math.pow(2, retryCount);
          setTimeout(() => {
            requestQueue.unshift({
              point,
              retryCount: retryCount + 1,
              resolve,
              reject,
            });
            processQueue();
          }, delay);
        } else {
          reject(e);
        }
      }
    }
  } finally {
    isProcessingQueue = false;
  }
}

// 共通Overpass API関数（クラス外に切り出し、または別モジュールに）
export async function fetchOverpassPlaces(
  lat,
  lon,
  radius,
  retries = 3,
  initialDelay = 1000
) {
  const r = Math.floor(radius);
  const query = `
    [out:json][timeout:180];  // デフォルトに近い適切なタイムアウト（180秒）
    node["place"~"^(neighbourhood|quarter|locality)$"]
      (around:${r},${lat},${lon});
    out body;
  `;
  const url =
    "https://overpass-api.de/api/interpreter?data=" + encodeURIComponent(query);

  let attempt = 0;
  while (attempt < retries) {
    attempt++;
    console.log(`[Overpass] Attempt ${attempt}/${retries}`);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // fetchのクライアント側タイムアウト: 30秒

    try {
      const res = await fetch(url, { signal: controller.signal });

      clearTimeout(timeoutId);

      if (!res.ok) {
        if (res.status === 429 || res.status >= 500) {
          // レートリミットやサーバーエラー: リトライ
          const delay = initialDelay * Math.pow(2, attempt - 1); // Exponential backoff
          console.warn(
            `❌ Overpass error: ${res.status}. Retrying after ${delay}ms...`
          );
          await new Promise((resolve) => setTimeout(resolve, delay));
          continue;
        }
        throw new Error(`Overpass HTTP error: ${res.status}`);
      }

      const json = await res.json();
      console.log("[Overpass] fetched elements =", json.elements.length);

      // フィルタリングして町字データを抽出
      const towns = json.elements
        .filter((el) => el.tags && el.tags.name)
        .map((el) => ({
          lat: el.lat,
          lng: el.lon,
          name: el.tags.name,
        }));

      return towns;
    } catch (e) {
      clearTimeout(timeoutId);
      if (e.name === "AbortError") {
        console.error("❌ Fetch timeout: Aborted after 30s");
      } else {
        console.error("❌ Overpass error:", e);
      }

      if (attempt === retries) {
        throw e; // 最終リトライ失敗
      }

      const delay = initialDelay * Math.pow(2, attempt - 1);
      console.warn(`Retrying after ${delay}ms...`);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw new Error("❌ Overpass max retries exceeded");
}
