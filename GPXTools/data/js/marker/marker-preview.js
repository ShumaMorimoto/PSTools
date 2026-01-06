import { notify } from "./../api-utils.js";

export default class MarkerPreview {
  constructor(selector, handler) {
    this.selector = selector;
    this.handler = handler;
    this.previewMarkers = [];

    // SearchControlへ注入するために自身のメソッドをbind
    this.onSelected = this.onSelected.bind(this);
  }

  // DI用：検索コントロールから呼ばれるエントリポイント
  onSelected(item, map, control, updateHistory) {
    this.clear(); // 以前のプレビューを消去
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
    }).addTo(this.selector.map);

    this.selector.map.setView(center, 16);

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

      // 履歴(localStorage)の更新
      container.querySelector(".update-hist-btn").onclick = () => {
        updateHistory({ name: nameInp.value, keyword: keyInp.value });
        notify("📋 履歴登録しました");
      };

      // 本登録
      container.querySelector(".confirm-btn").onclick = () => {
        const pos = pm.getLatLng();
        this.handler.addPoint({
          lat: pos.lat,
          lon: pos.lng,
          name: nameInp.value,
          extensions: { keyword: keyInp.value },
        });
        this.remove(pm);
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
    this.selector.map.removeLayer(pm);
    this.previewMarkers = this.previewMarkers.filter((x) => x !== pm);
  }

  clear() {
    this.previewMarkers.forEach((pm) => this.remove(pm));
  }
}
