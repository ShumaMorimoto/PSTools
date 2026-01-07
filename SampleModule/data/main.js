import { callApi, getStatus, shutdown } from '/lib/js/api-utils.js';

// 定期的にステータスを監視
setInterval(async () => {
    const state = await getStatus();
    document.getElementById('status').innerText = state.Phase;
}, 1000);

document.getElementById('runBtn').onclick = async () => {
    const res = await callApi('process', { input: 'Hello PowerShell!' });
    alert(res.message);
};

document.getElementById('stopBtn').onclick = () => shutdown();