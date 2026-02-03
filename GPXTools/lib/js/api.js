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

// js/api.js

/** 汎用 API 呼び出し */
export async function callApi(name, data = null) {
  // name が "TSPSolver" なら "/api/TSPSolver" になるように構成
  const url = `/api/${name.replace(/^\//, "")}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  });

  if (!res.ok) {
    // Pode側で catch して返している { Success: false, Error: "..." } を取得
    const errorJson = await res.json().catch(() => ({}));
    throw new Error(errorJson.Error || `Server Error: ${res.status}`);
  }
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
 * 現在の位置情報を取得する (Promise ラッパー)
 */
export function getCurrentPosition(options = { enableHighAccuracy: true }) {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error("Geolocation not supported"));
      return;
    }
    navigator.geolocation.getCurrentPosition(resolve, reject, options);
  });
}

/**
 * 位置情報をサーバーにアップロードする
 * 既存の callApi を再利用
 */
export async function uploadLocation() {
  try {
    const pos = await getCurrentPosition();
    const data = {
      lat: pos.coords.latitude,
      lon: pos.coords.longitude
    };
    // 既存の callApi を使って /api/location へ POST
    return await callApi("location", data);
  } catch (err) {
    console.error("Failed to upload location:", err);
    throw err;
  }
}