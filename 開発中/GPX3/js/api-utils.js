// api-utils.js (最終統合版)

const addressCache = new Map(); // キャッシュ

// シリアルキュー
const requestQueue = [];
let isProcessingQueue = false;


// js/api.js
const DEFAULT_POLL_INTERVAL = 1000;

/**
 * initialize: URL に ?init=true があれば /fetchInitialData を取得して返す
 * @returns {Promise<object|null>}
 */
export async function initialize() {
  const params = new URLSearchParams(window.location.search);
  if (params.get("init") !== "true") return null;
  const res = await fetch("/fetchInitialData");
  if (!res.ok) throw new Error(res.statusText);
  return res.json();
}

/**
 * uploadData
 * @param {object} obj
 * @returns {Promise<object>}
 */
export async function uploadData(obj) {
  const res = await fetch("/upload", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(obj),
  });
  if (!res.ok) throw new Error(res.statusText);
  return res.json();
}

/**
 * runSync
 * @param {object} obj
 * @param {string=} name - プロセス名（省略時 "default"）
 * @returns {Promise<object>}
 */
export async function runSync(obj, name) {
  const url = name ? `/processSync?name=${encodeURIComponent(name)}` : "/processSync";
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(obj),
  });
  if (!res.ok) throw new Error(res.statusText);
  return res.json();
}

/**
 * runAsync
 * @param {object} obj
 * @param {string=} name - プロセス名（省略時 "default"）
 * @returns {Promise<{jobId:string, status:string}>}
 */
export async function runAsync(obj, name) {
  const url = name ? `/processAsync?name=${encodeURIComponent(name)}` : "/processAsync";
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(obj),
  });
  if (!res.ok) throw new Error(res.statusText);
  return res.json();
}

/**
 * shutdown
 * @returns {Promise<object>}
 */
export async function shutdown() {
  const res = await fetch("/shutdown", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
  if (!res.ok) throw new Error(res.statusText);
  return res.json();
}

/**
 * pollResult (コールバック版)
 * @param {string} jobId
 * @param {number} intervalMs
 * @param {(status:string)=>void} onProgress
 * @param {(err:Error|null, result:object|null)=>void} onComplete
 * @returns {function():void} 停止用関数
 */
export function pollResult(
  jobId,
  intervalMs = DEFAULT_POLL_INTERVAL,
  onProgress,
  onComplete
) {
  const iv = setInterval(async () => {
    try {
      const res = await fetch(
        `/processAsyncResult?jobId=${encodeURIComponent(jobId)}`
      );
      if (!res.ok) throw new Error(res.statusText);
      const j = await res.json();
      if (j.status === "completed") {
        clearInterval(iv);
        onComplete?.(null, j.result);
      } else {
        onProgress?.(j.status);
      }
    } catch (e) {
      clearInterval(iv);
      onComplete?.(e, null);
    }
  }, intervalMs);
  return () => clearInterval(iv);
}

/**
 * pollUntilComplete (Promise版)
 * @param {string} jobId
 * @param {number} intervalMs
 * @param {(status:string)=>void} onProgress
 * @returns {Promise<object>}
 */
export function pollUntilComplete(
  jobId,
  intervalMs = DEFAULT_POLL_INTERVAL,
  onProgress
) {
  return new Promise((resolve, reject) => {
    const iv = setInterval(async () => {
      try {
        const res = await fetch(
          `/processAsyncResult?jobId=${encodeURIComponent(jobId)}`
        );
        if (!res.ok) throw new Error(res.statusText);
        const j = await res.json();
        if (j.status === "completed") {
          clearInterval(iv);
          resolve(j.result);
        } else {
          onProgress?.(j.status);
        }
      } catch (e) {
        clearInterval(iv);
        reject(e);
      }
    }, intervalMs);
  });
}

// api-utils.js

let muniCache = null;

// municipalities.json を内部キャッシュでロード
async function loadMunicipalitiesInternal() {
  if (muniCache) return muniCache;

  const res = await fetch("./municipalities.json");
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
  return muniData.municipalities.find(m => m.muniCd5 === muniCd5) || null;
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
  const muni = muniInfo.name;
  const url = `https://geolonia.github.io/japanese-addresses/api/ja/${pref}/${muni}.json`;

  try {
    const res = await fetch(url);
    return await res.json();
  } catch {
    return [];
  }
}

export async function fetchAddressAsync(
  point,
  marker,
  markerHandler,
  retryCount = 0
) {
  const seq = ++markerHandler.requestSeq;
  point._reqSeq = seq;

  const cacheKey = `${point.lat}_${point.lon}`;

  // ✅ キャッシュヒットは即処理（UIManager 連携済み）
  if (addressCache.has(cacheKey)) {
    const data = addressCache.get(cacheKey);
    processData(data, point, marker, markerHandler, seq);
    return;
  }

  // ✅ キューに積んでシリアル処理
  return new Promise((resolve, reject) => {
    requestQueue.push({
      point,
      marker,
      markerHandler,
      retryCount,
      seq,
      resolve,
      reject,
    });
    processQueue();
  });
}

async function processQueue() {
  if (isProcessingQueue || requestQueue.length === 0) return;
  isProcessingQueue = true;

  while (requestQueue.length > 0) {
    const { point, marker, markerHandler, retryCount, seq, resolve, reject } =
      requestQueue.shift();

    // ✅ Nominatim レート制限対策：1秒待つ
    await new Promise((resolve) => setTimeout(resolve, 1000));

    const cacheKey = `${point.lat}_${point.lon}`;

    // ✅ キャッシュチェック
    if (addressCache.has(cacheKey)) {
      const data = addressCache.get(cacheKey);
      processData(data, point, marker, markerHandler, seq);
      resolve();
      continue;
    }

    const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.lat}&lon=${point.lon}&zoom=18&addressdetails=1`;

    const headers = {
      "User-Agent": "MyMapApp/1.0 (contact@example.com)",
    };

    try {
      const res = await fetch(url, { headers });
      if (!res.ok) throw new Error(`HTTP error ${res.status}`);

      const data = await res.json();
      addressCache.set(cacheKey, data);

      processData(data, point, marker, markerHandler, seq);
      resolve();
    } catch (e) {
      console.log("Address fetch error", e);

      if (retryCount < 3) {
        const delay = 1000 * Math.pow(2, retryCount);
        console.log(`Retrying (${retryCount + 1}/3) after ${delay} ms`);

        setTimeout(() => {
          requestQueue.unshift({
            point,
            marker,
            markerHandler,
            retryCount: retryCount + 1,
            seq,
            resolve,
            reject,
          });
          processQueue();
        }, delay);
      } else {
        console.log("Max retries reached. Giving up.");
        reject(e);
      }
    }
  }

  isProcessingQueue = false;
}

// ------------------------------------------------------------
// ✅ UIManager と GPXModel に完全統合された processData
// ------------------------------------------------------------
function processData(data, point, marker, markerHandler, seq) {
  // ✅ 非同期逆転防止
  if (point._reqSeq !== seq) return;

  // ✅ 削除済みマーカーは無視
  if (!markerHandler.markers.some((entry) => entry.m === marker)) return;

  // ✅ GPXModel.trkpt の参照を直接更新（index 不使用）
  point.name = data.name || "";
  point.desc = data.display_name || "";
  point.extended = data.address || {};

  // ✅ マーカーのポップアップ更新
  try {
    marker.bindPopup(point.name || point.desc).openPopup();
  } catch (e) {}

  // ✅ UIManager.updateListUI() でリスト更新
  markerHandler.selector.uiManager.updateListUI();
}


// 共通Overpass API関数（クラス外に切り出し、または別モジュールに）
export async function fetchOverpassPlaces(lat, lon, radius, retries = 3, initialDelay = 1000) {
  const r = Math.floor(radius);
  const query = `
    [out:json][timeout:180];  // デフォルトに近い適切なタイムアウト（180秒）
    node["place"~"^(neighbourhood|quarter|locality)$"]
      (around:${r},${lat},${lon});
    out body;
  `;
  const url = "https://overpass-api.de/api/interpreter?data=" + encodeURIComponent(query);

  let attempt = 0;
  while (attempt < retries) {
    attempt++;
    console.log(`[Overpass] Attempt ${attempt}/${retries}`);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);  // fetchのクライアント側タイムアウト: 30秒

    try {
      const res = await fetch(url, { signal: controller.signal });

      clearTimeout(timeoutId);

      if (!res.ok) {
        if (res.status === 429 || res.status >= 500) {
          // レートリミットやサーバーエラー: リトライ
          const delay = initialDelay * Math.pow(2, attempt - 1);  // Exponential backoff
          console.warn(`❌ Overpass error: ${res.status}. Retrying after ${delay}ms...`);
          await new Promise(resolve => setTimeout(resolve, delay));
          continue;
        }
        throw new Error(`Overpass HTTP error: ${res.status}`);
      }

      const json = await res.json();
      console.log("[Overpass] fetched elements =", json.elements.length);

      // フィルタリングして町字データを抽出
      const towns = json.elements
        .filter(el => el.tags && el.tags.name)
        .map(el => ({
          lat: el.lat,
          lng: el.lon,
          name: el.tags.name,
        }));

      return towns;
    } catch (e) {
      clearTimeout(timeoutId);
      if (e.name === 'AbortError') {
        console.error("❌ Fetch timeout: Aborted after 30s");
      } else {
        console.error("❌ Overpass error:", e);
      }

      if (attempt === retries) {
        throw e;  // 最終リトライ失敗
      }

      const delay = initialDelay * Math.pow(2, attempt - 1);
      console.warn(`Retrying after ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw new Error("❌ Overpass max retries exceeded");
}