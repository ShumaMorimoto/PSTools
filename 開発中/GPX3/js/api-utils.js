// api-utils.js (最終統合版)

const addressCache = new Map(); // キャッシュ

// シリアルキュー
const requestQueue = [];
let isProcessingQueue = false;

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
