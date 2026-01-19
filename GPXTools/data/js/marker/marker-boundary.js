import { createPopupContent } from "./../components/leaflet-popup.js";
import { geoService } from "../components/geo-service.js";
import { notify } from "./../api-utils.js";
import {
  markerEvents,
  MarkerEventTypes,
  dispatchMarkerEvent,
} from "../marker/marker-events.js";
import { markerHistory } from "../marker/marker-history.js";

export default class MarkerBoundary {
  constructor(handler) {
    this.handler = handler;
    this.show = false;
    this.currentMuniCd5 = null;
    this._lastPoint = null;

    this.boundaryGroup = L.layerGroup();
    this.historyGroup = L.layerGroup();

    // 🔄 イベント購読：住所解決などの更新を検知してポップアップを同期
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      // 描画中の足跡マーカーの中から対象を探してリフレッシュ
      this.historyGroup.eachLayer((marker) => {
        if (marker.trkpt === point) {
          this.refreshPopup(marker);
        }
      });
    });

    markerEvents.addEventListener(MarkerEventTypes.POINT_SELECTED, (e) => {
      this._lastPoint = e.detail;
      this.redraw();
    });
  }

  _createFootprintIcon() {
    const svgPath = `M12,2c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S13.1,2,12,2z M7,7c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S8.1,7,7,7z M17,7 c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S18.1,7,17,7z M12,8c-2.2,0-4,1.8-4,4c0,1.5,0.8,2.8,2,3.5V18c0,1.1,0.9,2,2,2s2-0.9,2-2v-2.5 c1.2-0.7,2-2,2-3.5C16,9.8,14.2,8,12,8z`;
    return L.divIcon({
      className: "footprint-icon-container",
      html: `
        <div style="display: flex; align-items: center; justify-content: center; width: 30px; height: 30px;">
          <svg viewBox="0 0 24 24" width="28" height="28" style="filter: drop-shadow(0 0 1.5px #fff) drop-shadow(0 0 1.5px #fff) drop-shadow(0 0 1.5px #fff);">
            <path d="${svgPath}" fill="#28a745" />
          </svg>
        </div>`,
      iconSize: [30, 30],
      iconAnchor: [15, 15],
    });
  }

  init() {
    this.boundaryGroup.addTo(this.handler.map);
    this.historyGroup.addTo(this.handler.map);
  }

  setInteractive(enabled) {
    const mode = enabled ? "auto" : "none";
    this.historyGroup.eachLayer((marker) => {
      marker.options.interactive = enabled;
      const el = marker.getElement();
      if (el) {
        el.style.pointerEvents = mode;
      } else {
        marker.once("add", () => {
          marker.getElement().style.pointerEvents = mode;
        });
      }
      if (!enabled && marker.getPopup()) {
        marker.closePopup();
      }
    });
  }

  toggle() {
    this.show = !this.show;
    this.redraw();
  }

  redraw() {
    if (this.show && this._lastPoint) {
      this.render(this._lastPoint);
    } else {
      this.clear();
      this.currentMuniCd5 = null;
    }
  }

  async render(coord) {
    if (!coord || !coord.lat) return;
    try {
      const point = await geoService.resolveAddress({ ...coord });
      const muniCd = point.extensions?.muniCd5;
      if (!muniCd) {
        this.clear();
        return;
      }
      if (this.currentMuniCd5 !== muniCd) {
        this.boundaryGroup.clearLayers();
        const geo = await geoService.fetchBoundary(point);
        if (geo) {
          L.geoJSON(geo, {
            style: {
              color: "#ff6600",
              weight: 3,
              fill: true,
              fillColor: "#ff6600",
              fillOpacity: 0.05,
              interactive: false,
            },
          }).addTo(this.boundaryGroup);
        }
        this.currentMuniCd5 = muniCd;
      }
      this._plotLocalHistory(muniCd);
    } catch (e) {
      console.error("Boundary render error:", e);
    }
  }

  /**
   * ポップアップの表示・更新 (MarkerPreview と同等のロジック)
   */
  refreshPopup(marker) {
    const content = this._getPopupContent(marker);
    if (marker.getPopup()) {
      marker.setPopupContent(content);
    } else {
      marker.bindPopup(content, { minWidth: 240, maxWidth: 240 });
    }
  }

  /**
   * ポップアップの中身生成：地点登録ではなく「履歴の更新」を行う
   */
  _getPopupContent(marker) {
    // control への依存を減らし、markerHistory を直接使う
    return createPopupContent(marker.trkpt, marker, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },

      onUpdateAddress: async () => {
        try {
          await geoService.resolveAddress(marker.trkpt);

          // 💾 2. 保存ロジックを markerHistory に集約
          markerHistory.save(marker.trkpt);

          dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
            point: marker.trkpt,
          });
          notify("🔄 住所情報を照会しました");
        } catch (err) {
          notify("❌ 住所照会失敗");
        }
      },

      onSave: (newData) => {
        marker.trkpt.name = newData.name;
        marker.trkpt.desc = newData.desc;
        if (marker.trkpt.extensions) {
          marker.trkpt.extensions.keyword = newData.extensions?.keyword;
        }

        // 💾 2. 保存ロジックを markerHistory に集約
        markerHistory.save(marker.trkpt);

        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
          point: marker.trkpt,
        });
        notify("💾 検索履歴を更新しました");
      },

      onDelete: () => {
        // 💾 3. 履歴からの削除も markerHistory を使用
        markerHistory.delete(marker.trkpt);
        this.historyGroup.removeLayer(marker);
        notify("🗑 履歴から削除しました");
      },
    });
  }

_plotLocalHistory(muniCd) {
    this.historyGroup.clearLayers();
    const localItems = markerHistory.getByMuniCd(muniCd);
    const footprintIcon = this._createFootprintIcon();

    localItems.forEach((item) => {
      const marker = L.marker([item.lat, item.lon], {
        icon: footprintIcon,
        zIndexOffset: 500,
        draggable: true, // 1. ドラッグを有効化
        interactive: (this.handler.state === "idle")
      }).addTo(this.historyGroup);

      marker.trkpt = item;

      // --- ドラッグ終了時の処理を追加 ---
      marker.on("dragend", async (e) => {
        const pos = e.target.getLatLng();
        // 座標を更新
        marker.trkpt.lat = pos.lat;
        marker.trkpt.lon = pos.lng;
        marker.trkpt.desc = null;
        marker.trkpt.extensions.muniCd5 = null;
        
        // 2. 住所を再解決（オプション）
        try {
          await geoService.resolveAddress(marker.trkpt);
        } catch (err) {
          console.error("足跡移動時の住所解決失敗:", err);
        }

        // 3. 履歴に保存（markerHistory に集約）
        markerHistory.save(marker.trkpt);

        // 4. UI更新を通知
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: marker.trkpt });
        notify("📍 足跡の位置を修正しました");
      });

      this.refreshPopup(marker);
      marker.bindTooltip(item.name);

      marker.on("click", (e) => {
        L.DomEvent.stopPropagation(e);
        marker.openPopup();
      });
    });
  }

  clear() {
    this.boundaryGroup.clearLayers();
    this.historyGroup.clearLayers();
  }
}
