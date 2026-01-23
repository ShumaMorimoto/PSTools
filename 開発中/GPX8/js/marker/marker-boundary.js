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

    // 🚩 境界線用とマーカー用でグループを分ける
    this.boundaryGroup = L.layerGroup();
    this.historyGroup = L.layerGroup();

    // イベント購読
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      this.historyGroup.eachLayer((marker) => {
        if (marker.trkpt === point) {
          this.refreshPopup(marker);
        }
      });
    });

    markerEvents.addEventListener(MarkerEventTypes.POINT_SELECTED, (e) => {
      this._lastPoint = e.detail;
      if (this.show) this.redraw();
    });
  }

  init() {
    // 🚩 境界線を先に、マーカーを後に追加して重なり順を固定
    this.boundaryGroup.addTo(this.handler.map);
    this.historyGroup.addTo(this.handler.map);
  }

  // 🚩 最初のコードで確実だった「DOMレベルの透過制御」を継承
  setInteractive(enabled) {
    const mode = enabled ? "auto" : "none";
    this.historyGroup.eachLayer((marker) => {
      marker.options.interactive = enabled;
      const el = marker.getElement();
      if (el) el.style.pointerEvents = mode;
      if (!enabled && marker.getPopup()) marker.closePopup();
    });
  }

  toggle() {
    this.show = !this.show;
    this.redraw();
    this.setInteractive(this.handler.state === "idle");
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
              interactive: false, // 🚩 境界線はクリックを透過させる
            },
          }).addTo(this.boundaryGroup);
        }
        this.currentMuniCd5 = muniCd;
      }
      // 🚩 ここでマーカーを描画（最初の動くロジックを直接実行）
      this._plotLocalHistory(muniCd);
    } catch (e) {
      console.error("Boundary render error:", e);
    }
  }

  _plotLocalHistory(muniCd) {
    this.historyGroup.clearLayers();
    const localItems = markerHistory.getByMuniCd(muniCd);
    const footprintIcon = this._createFootprintIcon();

    const isIdle = this.handler.state === "idle";
    const pointerMode = isIdle ? "auto" : "none";

    localItems.forEach((item) => {
      const marker = L.marker([item.lat, item.lon], {
        icon: footprintIcon,
        zIndexOffset: 1000, // 🚩 境界線より確実に上に来るように
        draggable: isIdle,
        interactive: true,
      }).addTo(this.historyGroup);

      marker.trkpt = item;

      // 🚩 最初のコードで成功していた add 直後の制御
      marker.once("add", () => {
        const el = marker.getElement();
        if (el) {
          el.style.pointerEvents = pointerMode;
          el.style.cursor = isIdle ? "pointer" : "default";
        }
      });

      // ポップアップとイベント設定
      this.refreshPopup(marker);
      marker.bindTooltip(item.name || "");

      // 🚩 明示的なクリックイベント（これが一番確実）
      marker.on("click", (e) => {
        L.DomEvent.stopPropagation(e);
        if (this.handler.state === "idle") marker.openPopup();
      });

      // ドラッグ終了時の更新処理
      marker.on("dragend", async (e) => {
        const pos = e.target.getLatLng();
        marker.trkpt.lat = pos.lat;
        marker.trkpt.lon = pos.lng;
        if (marker.trkpt.extensions) marker.trkpt.extensions.muniCd5 = null;

        await geoService.resolveAddress(marker.trkpt);
        markerHistory.save(marker.trkpt);
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: marker.trkpt });
        notify("📍 足跡の位置を修正しました");
      });
    });
  }

  refreshPopup(marker) {
    const content = this._getPopupContent(marker);
    if (marker.getPopup()) {
      marker.setPopupContent(content);
    } else {
      marker.bindPopup(content, { minWidth: 240, maxWidth: 240 });
    }
  }

  _getPopupContent(marker) {
    return createPopupContent(marker.trkpt, marker, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },
      onUpdateAddress: async () => {
        try {
          await geoService.resolveAddress(marker.trkpt);
          markerHistory.save(marker.trkpt);
          dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: marker.trkpt });
          notify("🔄 住所情報を更新");
        } catch (err) { notify("❌ 更新失敗"); }
      },
      onSave: (newData) => {
        Object.assign(marker.trkpt, { name: newData.name, desc: newData.desc });
        markerHistory.save(marker.trkpt);
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: marker.trkpt });
        notify("💾 保存完了");
      },
      onDelete: () => {
        markerHistory.delete(marker.trkpt);
        this.historyGroup.removeLayer(marker);
        notify("🗑 削除しました");
      }
    });
  }

  _createFootprintIcon() {
    const svgPath = `M12,2c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S13.1,2,12,2z M7,7c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S8.1,7,7,7z M17,7 c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S18.1,7,17,7z M12,8c-2.2,0-4,1.8-4,4c0,1.5,0.8,2.8,2,3.5V18c0,1.1,0.9,2,2,2s2-0.9,2-2v-2.5 c1.2-0.7,2-2,2-3.5C16,9.8,14.2,8,12,8z`;
    return L.divIcon({
      className: "footprint-marker",
      html: `<div style="display:flex;align-items:center;justify-content:center;width:30px;height:30px;"><svg viewBox="0 0 24 24" width="28" height="28" style="filter:drop-shadow(0 0 1.5px #fff);"><path d="${svgPath}" fill="#28a745" /></svg></div>`,
      iconSize: [30, 30],
      iconAnchor: [15, 15],
    });
  }

  clear() {
    this.boundaryGroup.clearLayers();
    this.historyGroup.clearLayers();
  }
}