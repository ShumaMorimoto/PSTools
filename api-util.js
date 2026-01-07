/**
 * API呼び出しの基底関数
 * @param {string} name - APIの名前 (例: 'tsp', 'address', 'status')
 * @param {Object} data - 送信するデータオブジェクト
 * @returns {Promise<Object>}
 */
export async function callApi(name, data = {}) {
  // /shutdown だけは例外として扱い、その他は /api/ を付与する
  const endpoint = name === 'shutdown' || name === '/shutdown' 
    ? '/shutdown' 
    : `/api/${name.replace(/^\//, '')}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  });

  if (!response.ok) {
    const errorDetail = await response.json().catch(() => ({}));
    throw new Error(errorDetail.error || `Server Error: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * 現在の共有状態（GlobalState）を取得する
 */
export async function getStatus() {
  return await callApi('status');
}

/**
 * サーバーをシャットダウンする
 */
export async function shutdown() {
  try {
    const res = await callApi('shutdown');
    console.log("Shutdown initiated:", res.message);
    setTimeout(() => {
      window.close();
    }, 500);
  } catch (err) {
    console.error("Shutdown failed:", err);
  }
}