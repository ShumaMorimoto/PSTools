import { geoService } from "./../components/geo-service.js"; // インスタンスをインポート
import { notify } from "./../api-utils.js"; // notifyは既存のものを利用

export default class MarkerPreview {
  constructor(handler) {
    this.handler = handler;
    this.previewMarkers = [];
    this.onSelected = this.onSelected.bind(this);
  }

  onSelected(item, map, control, updateHistory) {
    this.clear();
    this.add(item, updateHistory);
  }

  add(trkpt, updateHistory) {
    const pm = this._createPreviewMarker(trkpt, updateHistory);
    this.previewMarkers.push(pm);
    return pm;
  }

  _createPreviewMarker(trkpt, updateHistory) {
    const center = [trkpt.lat, trkpt.lon];
    const initialName = trkpt.name || "";
    const initialKeyword = trkpt.extensions?.keyword || "";

    const previewIcon = L.divIcon({
      className: "preview-marker",
      html: `<div style="width:24px; height:24px; border-radius:50%; background: rgba(255, 80, 80, 0.8); border: 2px solid #900; box-shadow: 0 0 4px rgba(0,0,0,0.6);"></div>`,
      iconSize: [24, 24],
      iconAnchor: [12, 12],
    });

    const pm = L.marker(center, {
      draggable: true,
      icon: previewIcon,
    }).addTo(this.handler.map);

    this.handler.map.setView(center, 16);

    const container = document.createElement("div");
    container.style.width = "200px";
    container.innerHTML = `
      <div style="margin-bottom:8px;">
        <label style="font-size:10px; color:#888;">拠点名</label>
        <input type="text" class="edit-name" value="${initialName}" style="width:100%; border:1px solid #ccc; padding:2px;">
        <label style="font-size:10px; color:#888; margin-top:5px; display:block;">キーワード</label>
        <input type="text" class="edit-key" value="${initialKeyword}" style="width:100%; border:1px solid #ccc; padding:2px;">
      </div>
      <div style="display: flex; gap: 4px;">
        <button class="update-hist-btn" style="flex:1; font-size:10px; padding:4px 0; cursor:pointer; background:#f8f9fa; border:1px solid #ccc; color:#333;">履歴保存</button>
        <button class="confirm-btn" style="flex:1; font-size:10px; padding:4px 0; cursor:pointer; background:#2196f3; border:1px solid #1976d2; color:white; font-weight:bold;">地点登録</button>
      </div>
    `;

    pm.bindPopup(container);

    pm.on("popupopen", () => {
      const nameInp = container.querySelector(".edit-name");
      const keyInp = container.querySelector(".edit-key");

      container.querySelector(".update-hist-btn").onclick = () => {
        updateHistory({ name: nameInp.value, keyword: keyInp.value });
        notify("📋 履歴登録しました");
      };

      // 本登録ボタンのロジック
      container.querySelector(".confirm-btn").onclick = async () => {
        const pos = pm.getLatLng();
        
        // ★ 登録直前に自治体・町字情報を解決
        const resolved = await geoService.resolve({ lat: pos.lat, lon: pos.lng });

        this.handler.addPoint({
          lat: pos.lat,
          lon: pos.lng,
          // 入力があればそれを優先、なければGSIから取得した地名をセット
          name: nameInp.value || resolved.name,
          desc: resolved.desc,
          extensions: {
            ...(resolved.extensions || {}),
            keyword: keyInp.value
          },
        });
        this.remove(pm);
        notify(`📍 ${nameInp.value || resolved.name} を登録しました`);
      };
    });

    pm.on("dragend", (e) => {
      const pos = e.target.getLatLng();
      updateHistory({ lat: pos.lat, lon: pos.lng });
    });

    pm._timer = setTimeout(() => this.remove(pm), 180000);
    return pm;
  }

  remove(pm) {
    clearTimeout(pm._timer);
    this.handler.map.removeLayer(pm);
    this.previewMarkers = this.previewMarkers.filter((x) => x !== pm);
  }

  clear() {
    this.previewMarkers.forEach((pm) => this.remove(pm));
  }
}