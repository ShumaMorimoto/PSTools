import { createPopupContent } from "./../components/leaflet-popup.js";
import { geoService } from "./../components/geo-service.js";
import { notify } from "./../api-utils.js";

export default class MarkerPreview {
  constructor(handler) {
    this.handler = handler;
    this.previewMarkers = [];
    this.onSelected = this.onSelected.bind(this);
  }

  onSelected(item, map, control) {
    this.clear();
    const trkpt = {
      lat: item.lat,
      lon: item.lon || item.lng,
      name: item.name || item.display_name,
      desc: item.desc || "",
      extensions: item.extensions || {}
    };
    this.add(trkpt, control);
  }

  add(trkpt, control) {
    const pm = this._createPreviewMarker(trkpt, control);
    this.previewMarkers.push(pm);
    return pm;
  }

  /**
   * 本マーカーの refresh(marker) と同じ思想の処理
   * データを最新の状態にして、ポップアップの中身を完全に差し替える
   */
  refreshPopup(pm, control) {
    const content = this._getPopupContent(pm, control);
    // すでにポップアップが開いている場合は内容を更新、そうでなければバインド
    if (pm.getPopup()) {
      pm.setPopupContent(content);
    } else {
      pm.bindPopup(content, { minWidth: 240, maxWidth: 240 }).openPopup();
    }
  }

  /**
   * ポップアップのHTML要素生成（本マーカーの getContent に相当）
   */
  _getPopupContent(pm, control) {
    return createPopupContent(pm.trkpt, pm, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },

      // 🔄 住所更新：本マーカーと同様に、データを更新してから refresh をかける
      onUpdateAddress: async () => {
        const pos = pm.getLatLng();
        const res = await geoService.resolve({ lat: pos.lat, lon: pos.lng });
        
        // 1. 内部保持データを更新（これで編集遷移時もOK）
        pm.trkpt.desc = res.desc || "";
        
        // 2. 本マーカーの思想に合わせ、ポップアップを再描画して表示を同期
        this.refreshPopup(pm, control);
        
        notify("🔄 住所情報を照会しました");
      },

      // 💾 保存
      onSave: (newData) => {
        const pos = pm.getLatLng();
        if (control && control._saveToHistory) {
          control._saveToHistory({
            lat: pos.lat,
            lon: pos.lng,
            name: newData.name,
            desc: newData.desc,
            extensions: { keyword: newData.keyword }
          });
          
          // データを更新して再描画
          pm.trkpt.name = newData.name;
          pm.trkpt.desc = newData.desc;
          this.refreshPopup(pm, control);

          notify("💾 検索履歴を更新しました");
        }
      },

      onDelete: () => this.remove(pm)
    });
  }

  _createPreviewMarker(trkpt, control) {
    const pm = L.marker([trkpt.lat, trkpt.lon], {
      draggable: true,
      icon: L.divIcon({
        className: "preview-marker",
        html: `<div style="width:24px; height:24px; border-radius:50%; background: rgba(255, 80, 80, 0.8); border: 2px solid #900;"></div>`,
        iconSize: [24, 24],
        iconAnchor: [12, 12],
      }),
    }).addTo(this.handler.map);

    // データをマーカーに紐付け
    pm.trkpt = trkpt;

    this.handler.map.setView(pm.getLatLng(), 16);

    // 初期ポップアップ表示
    this.refreshPopup(pm, control);

    // ドラッグ時
    pm.on("dragend", async (e) => {
      const pos = e.target.getLatLng();
      pm.trkpt.lat = pos.lat;
      pm.trkpt.lon = pos.lng;
      
      // ドラッグ後も住所を自動更新して再描画
      const res = await geoService.resolve({ lat: pos.lat, lon: pos.lng });
      pm.trkpt.desc = res.desc || "";
      this.refreshPopup(pm, control);
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