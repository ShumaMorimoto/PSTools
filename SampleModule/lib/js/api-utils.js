export async function callApi(name, data = {}) {
    const endpoint = name === 'shutdown' ? '/shutdown' : `/api/${name.replace(/^\//, '')}`;
    const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data)
    });
    if (!response.ok) throw new Error("API Error");
    return await response.json();
}

export const getStatus = () => callApi('status');
export const shutdown = () => callApi('shutdown').then(() => window.close());