import { createPopupContent } from "./../components/leaflet-popup.js";
import { geoService } from "./../components/geo-service.js";
import { notify } from "./../api-utils.js";
import {
  markerEvents,
  MarkerEventTypes,
  dispatchMarkerEvent,
} from "../marker/marker-events.js";
import { markerHistory } from "../marker/marker-history.js"; // ← 追加

/**
 * 検索結果などの一時的なプレビューマーカーを管理するクラス。
 * 本マーカーと同様のイベント駆動（POINT_UPDATED）により UI 同期を行う。
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

      // 管理しているプレビューマーカーであれば、ポップアップを最新化する
      if (pm) {
        this.refreshPopup(pm);
      }
    });
  }

  /**
   * ポイント参照（trkpt）からプレビューマーカーを特定する
   */
  getPreviewByPoint(point) {
    return this.previewMarkers.find((pm) => pm.trkpt === point);
  }

  /**
   * 検索結果が選択された際の処理
   */
  async onSelected(item) {
    this.clear();

    // 1. 元のデータを汚さないようコピーを作成
    const trkpt = { ...item };
    const pm = this.add(trkpt);

    // 2. Web検索結果等の場合は住所情報を補完
    if (item.source === "web") {
      try {
        await geoService.resolveAddress(pm.trkpt);

        // 💾 履歴を更新（上書き保存）
        markerHistory.save(pm.trkpt);

        // 📣 更新イベントを発行
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
          point: pm.trkpt,
        });
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
   * ポップアップの中身を完全に差し替える（表示の同期）
   */
  refreshPopup(pm) {
    const content = this._getPopupContent(pm);
    if (pm.getPopup()) {
      pm.setPopupContent(content);
    } else {
      pm.bindPopup(content, { minWidth: 240, maxWidth: 240 }).openPopup();
    }
  }

  /**
   * ポップアップのHTML要素生成
   */
  _getPopupContent(pm) {
    return createPopupContent(pm.trkpt, pm, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },

      onUpdateAddress: async () => {
        const pos = pm.getLatLng();
        pm.trkpt.lat = pos.lat;
        pm.trkpt.lon = pos.lng;

        await geoService.resolveAddress(pm.trkpt);

        // 💾 照会した住所を履歴に保存
        markerHistory.save(pm.trkpt);

        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
          point: pm.trkpt,
        });
        notify("🔄 住所情報を照会しました");
      },

      onSave: (newData) => {
        const pos = pm.getLatLng();
        pm.trkpt.name = newData.name;
        pm.trkpt.desc = newData.desc;
        pm.trkpt.lat = pos.lat;
        pm.trkpt.lon = pos.lng;
        if (pm.trkpt.extensions) {
          pm.trkpt.extensions.keyword = newData.extensions.keyword;
        }

        // 💾 編集内容を履歴に保存
        markerHistory.save(pm.trkpt);

        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
          point: pm.trkpt,
        });
        notify("💾 検索履歴を更新しました");
      },

      onDelete: () => this.remove(pm),
    });
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

    pm.trkpt = trkpt;
    this.handler.map.setView(pm.getLatLng(), 16);

    // 初期表示
    this.refreshPopup(pm);

    // ドラッグ時：本マーカーと同様の座標反映と住所解決
    pm.on("dragend", async (e) => {
      const pos = e.target.getLatLng();
      pm.trkpt.lat = pos.lat;
      pm.trkpt.lon = pos.lng;
      pm.trkpt.desc = null;
      pm.trkpt.extensions.muniCd5 = null;

      // geoService で住所を再解決
      await geoService.resolveAddress(pm.trkpt);

      // 履歴に反映
      // 💾 ドラッグ後の座標と住所を履歴に反映
      markerHistory.save(pm.trkpt);

      // 📣 通知してポップアップを更新
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
