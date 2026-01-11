import { createPopupContent } from "./../components/leaflet-popup.js";
import { geoService } from "./../components/geo-service.js";
import { notify } from "./../api-utils.js";

export default class MarkerPreview {
  constructor(handler) {
    this.handler = handler; // Map参照用
    this.previewMarkers = [];
    this.onSelected = this.onSelected.bind(this);
  }

  onSelected(item, map, control, updateHistory) {
    this.clear();
    const trkpt = {
      lat: item.lat,
      lon: item.lon || item.lng,
      name: item.name || item.display_name,
      desc: item.desc || "",
      extensions: item.extensions || {}
    };
    this.add(trkpt, updateHistory);
  }

  add(trkpt, updateHistory) {
    const pm = this._createPreviewMarker(trkpt, updateHistory);
    this.previewMarkers.push(pm);
    return pm;
  }

  _createPreviewMarker(trkpt, updateHistory) {
    const pm = L.marker([trkpt.lat, trkpt.lon], {
      draggable: true,
      icon: L.divIcon({
        className: "preview-marker",
        html: `<div style="width:24px; height:24px; border-radius:50%; background: rgba(255, 80, 80, 0.8); border: 2px solid #900;"></div>`,
        iconSize: [24, 24],
        iconAnchor: [12, 12],
      }),
    }).addTo(this.handler.map);

    this.handler.map.setView(pm.getLatLng(), 16);

    const content = createPopupContent(trkpt, pm, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },

      // 🔄：住所を照会し、履歴データとしての精度を上げる
      onUpdateAddress: async () => {
        const pos = pm.getLatLng();
        const res = await geoService.resolve({ lat: pos.lat, lon: pos.lng });
        content.querySelector('[name="desc"]').value = res.desc || "";
        notify("🔄 住所情報を照会しました");
      },

      // 保存：LocalStorage（履歴）を更新する。モデル（本登録）へは絶対に触れない
      onSave: (newData) => {
        const pos = pm.getLatLng();
        updateHistory({
          lat: pos.lat,
          lon: pos.lng,
          name: newData.name,
          desc: newData.desc,
          keyword: newData.keyword
        });
        
        // Popup内の表示を反映
        content.querySelector(".p-title").innerText = newData.name;
        content.querySelector(".p-desc").innerText = newData.desc;
        notify("💾 検索履歴を更新しました");
      },

      // 通常時の戻る：仮マーカーを消去
      onDelete: () => this.remove(pm)
    });

    pm.bindPopup(content, { minWidth: 240, maxWidth: 240 }).openPopup();

    // ドラッグ時もモデルとは無関係に「履歴」の座標のみ同期
    pm.on("dragend", (e) => {
      const pos = e.target.getLatLng();
      updateHistory({ lat: pos.lat, lon: pos.lng });
      content.querySelector("#p-header-coord").innerText = `📍 ${pos.lat.toFixed(5)}, ${pos.lng.toFixed(5)}`;
    });

    pm._timer = setTimeout(() => this.remove(pm), 180000);
    return pm;
  }

  remove(pm) {
    if (!pm) return;
    clearTimeout(pm._timer);
    this.handler.map.removeLayer(pm);
    this.previewMarkers = this.previewMarkers.filter((x) => x !== pm);
  }

  clear() {
    this.previewMarkers.forEach((pm) => this.remove(pm));
    this.previewMarkers = [];
  }
}