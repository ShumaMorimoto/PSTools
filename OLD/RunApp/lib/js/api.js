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
  const res = await fetch(`/api?name=${encodeURIComponent(name)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: data ? JSON.stringify(data) : "{}",
  });

  if (!res.ok) throw new Error(res.statusText);
  return res.json();
}

/** GET 系 API（POST したくない場合用） */
export async function callApiGet(name) {
  const res = await fetch(`/api?name=${encodeURIComponent(name)}`);
  if (!res.ok) throw new Error(res.statusText);
  return res.json();
}

/** ポーリング（汎用） */
export function pollApi(name, intervalMs, onUpdate) {
  const iv = setInterval(async () => {
    try {
      const result = await callApi(name);
      onUpdate?.(result);
    } catch (e) {
      console.error("pollApi error:", e);
    }
  }, intervalMs);

  return () => clearInterval(iv);
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
