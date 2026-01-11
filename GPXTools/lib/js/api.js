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
