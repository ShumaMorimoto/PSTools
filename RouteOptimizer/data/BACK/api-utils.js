// api-utils.js (修正版)

const addressCache = new Map(); // 簡易キャッシュ（Nominatim制約対策）

export async function fetchAddressAsync(point, marker, markerHandler, retryCount = 0) {
    const maxRetries = 3;
    const baseDelay = 1000; // 1 second base delay
    const seq = ++markerHandler.requestSeq;
    point._reqSeq = seq;

    const cacheKey = `${point.lat}_${point.lon}`;
    if (addressCache.has(cacheKey)) {
        const data = addressCache.get(cacheKey);
        console.log('Cache hit:', data);
        processData(data);
        return;
    }

    // Nominatimレート制限対策: 1秒遅延
    await new Promise(resolve => setTimeout(resolve, 1000));

    const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.lat}&lon=${point.lon}&zoom=18&addressdetails=1`;

    // Nominatim制約対策: カスタムUser-Agent
    const headers = {
        'User-Agent': 'MyMapApp/1.0 (contact@example.com)' // アプリ識別子と連絡先を設定
    };

    try {
        const res = await fetch(url, { headers });
        if (!res.ok) {
            throw new Error(`HTTP error! status: ${res.status}`);
        }
        const data = await res.json();
        addressCache.set(cacheKey, data); // キャッシュ保存
        processData(data);
    } catch (e) {
        console.log("Address fetch error", e);
        if (retryCount < maxRetries) {
            const delay = baseDelay * Math.pow(2, retryCount); // Exponential backoff
            console.log(`Retrying fetchAddressAsync (${retryCount + 1}/${maxRetries}) after ${delay} ms`);
            setTimeout(() => {
                fetchAddressAsync(point, marker, markerHandler, retryCount + 1);
            }, delay);
        } else {
            console.log("Max retries reached. Giving up.");
        }
    }

    function processData(data) {
        if (point._reqSeq !== seq) return;
        if (!markerHandler.markers.includes(marker)) return;

        point.name = data.name || "";
        point.desc = data.display_name || "";
        point.extended = data.address || {};

        try {
            marker.bindPopup(point.name || point.desc).openPopup();
        } catch (e) { /* ignore */ }
        markerHandler.selector.uiManager.updateListUI();
    }
}