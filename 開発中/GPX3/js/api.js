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
 * @returns {Promise<object>}
 */
export async function runSync(obj) {
  const res = await fetch("/processSync", {
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
 * @returns {Promise<{jobId:string, status:string}>}
 */
export async function runAsync(obj) {
  const res = await fetch("/processAsync", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(obj),
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
