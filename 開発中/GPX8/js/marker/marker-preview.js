import { geoService } from "./../components/geo-service.js";
import {
  markerEvents,
  MarkerEventTypes,
  dispatchMarkerEvent,
} from "../marker/marker-events.js";
import { markerHistory } from "../marker/marker-history.js";

/**
 * 検索結果などの一時的なプレビューマーカーを管理するクラス。
 */
export default class MarkerPreview {
  constructor(handler) {
    this.handler = handler;
    this.previewMarkers = []; // Leafletマーカーの配列
    this.onSelected = this.onSelected.bind(this);

    // 🔄 イベント購読：データ更新を検知してポップアップをリフレッシュ
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      const pm = this.getPreviewByPoint(point);

      if (pm) {
        // 集約されたPopupクラスにリフレッシュを依頼
        this.handler.popup.bindPreview(pm);
      }
    });
  }

  getPreviewByPoint(point) {
    return this.previewMarkers.find((pm) => pm.trkpt === point);
  }

  async onSelected(item) {
    this.clear();
    const trkpt = { ...item };
    const pm = this.add(trkpt);

    if (item.source === "web") {
      try {
        await geoService.resolveAddress(pm.trkpt);
        markerHistory.save(pm.trkpt);
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: pm.trkpt });
      } catch (err) {
        console.error("プレビュー住所補完失敗:", err);
      }
    }
  }

  add(trkpt) {
    const pm = this._createPreviewMarker(trkpt);
    this.previewMarkers.push(pm);
    return pm;
  }

  /**
   * ポップアップ表示のブリッジ（MarkerPopupへ委譲）
   */
  refreshPopup(pm) {
    if (!pm) return;
    this.handler.popup.bindPreview(pm);
    pm.openPopup();
  }

  _createPreviewMarker(trkpt) {
    const pm = L.marker([trkpt.lat, trkpt.lon], {
      draggable: true,
      icon: L.divIcon({
        className: "preview-marker",
        html: `<div style="width:24px; height:24px; border-radius:50%; background: rgba(255, 80, 80, 0.8); border: 2px solid #900;"></div>`,
        iconSize: [24, 24],
        iconAnchor: [12, 12],
      }),
    }).addTo(this.handler.map);

    // 1. データを保持
    pm.trkpt = trkpt;
    this.handler.map.setView(pm.getLatLng(), 16);

    // 2. 集約クラスにバインド（ここでポップアップが生成される）
    this.handler.popup.bindPreview(pm);
    pm.openPopup();

    // ドラッグ時：座標反映と住所解決
    pm.on("dragend", async (e) => {
      const pos = e.target.getLatLng();
      pm.trkpt.lat = pos.lat;
      pm.trkpt.lon = pos.lng;
      pm.trkpt.desc = null;
      if (pm.trkpt.extensions) pm.trkpt.extensions.muniCd5 = null;

      await geoService.resolveAddress(pm.trkpt);
      markerHistory.save(pm.trkpt);

      dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: pm.trkpt });
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