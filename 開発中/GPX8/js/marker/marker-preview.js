import { createPopupContent } from "./../components/leaflet-popup.js";
import { geoService } from "./../components/geo-service.js";
import { notify } from "./../api-utils.js";
import { markerEvents, MarkerEventTypes, dispatchMarkerEvent } from "../marker/marker-events.js";

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
  async onSelected(item, map, control) {
    this.clear();
    
    // 1. 元のデータを汚さないようコピーを作成（プレビュー用の独立した参照）
    const trkpt = { ...item }; 
    const pm = this.add(trkpt, control);

    // 2. Web検索結果等の場合は住所情報を補完
    if (item.source === "web") {
      try {
        // geoService が pm.trkpt を直接書き換える
        await geoService.resolveAddress(pm.trkpt);
//        await geoService.resolve(pm.trkpt);

        // 住所が詳細になったので履歴を更新（上書き）
        if (control?._saveToHistory) control._saveToHistory(pm.trkpt);

        // 📣 更新イベントを発行（constructor 内のリスナー経由で refreshPopup が呼ばれる）
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: pm.trkpt });
      } catch (err) {
        console.error("プレビュー住所補完失敗:", err);
      }
    }
  }

  add(trkpt, control) {
    const pm = this._createPreviewMarker(trkpt, control);
    this.previewMarkers.push(pm);
    return pm;
  }

  /**
   * ポップアップの中身を完全に差し替える（表示の同期）
   */
  refreshPopup(pm, control) {
    const content = this._getPopupContent(pm, control);
    if (pm.getPopup()) {
      pm.setPopupContent(content);
    } else {
      pm.bindPopup(content, { minWidth: 240, maxWidth: 240 }).openPopup();
    }
  }

  /**
   * ポップアップのHTML要素生成
   */
  _getPopupContent(pm, control) {
    return createPopupContent(pm.trkpt, pm, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },

      // 🔄 住所更新：本マーカーと同様のフロー
      onUpdateAddress: async () => {
        const pos = pm.getLatLng();
        pm.trkpt.lat = pos.lat;
        pm.trkpt.lon = pos.lng;

        // 直接データをリッチにする
        await geoService.resolveAddress(pm.trkpt);

        // 更新を通知
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: pm.trkpt });
        notify("🔄 住所情報を照会しました");
      },

      // 💾 履歴への保存
      onSave: (newData) => {
        const pos = pm.getLatLng();
        // データを手動更新
        pm.trkpt.name = newData.name;
        pm.trkpt.desc = newData.desc;
        pm.trkpt.lat = pos.lat;
        pm.trkpt.lon = pos.lng;
        if (pm.trkpt.extensions) {
          pm.trkpt.extensions.keyword = newData.keyword;
        }

        if (control?._saveToHistory) {
          control._saveToHistory(pm.trkpt);
        }

        // 通知して UI をリフレッシュ
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: pm.trkpt });
        notify("💾 検索履歴を更新しました");
      },

      onDelete: () => this.remove(pm),
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

    pm.trkpt = trkpt;
    this.handler.map.setView(pm.getLatLng(), 16);

    // 初期表示
    this.refreshPopup(pm, control);

    // ドラッグ時：本マーカーと同様の座標反映と住所解決
    pm.on("dragend", async (e) => {
      const pos = e.target.getLatLng();
      pm.trkpt.lat = pos.lat;
      pm.trkpt.lon = pos.lng;

      // geoService で住所を再解決
      await geoService.resolveAddress(pm.trkpt);

      // 履歴に反映
      if (control?._saveToHistory) {
        control._saveToHistory(pm.trkpt);
      }

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