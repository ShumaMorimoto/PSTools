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

    // 🔄 MarkerPopupが POINT_UPDATED を監視してリフレッシュしてくれるため、
    // ここでの個別リスナーは不要になります（MarkerPopup側のコンストラクタで一括処理）

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
      if (el) el.style.pointerEvents = mode;
      if (!enabled && marker.getPopup()) marker.closePopup();
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

  getMarkerByPoint(point) {
    let target = null;
    this.historyGroup.eachLayer((marker) => {
      if (marker.trkpt === point) target = marker;
    });
    return target;
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

  _plotLocalHistory(muniCd) {
    this.historyGroup.clearLayers();
    const localItems = markerHistory.getByMuniCd(muniCd);
    const footprintIcon = this._createFootprintIcon();

    localItems.forEach((item) => {
      const marker = L.marker([item.lat, item.lon], {
        icon: footprintIcon,
        zIndexOffset: 500,
        draggable: true,
        interactive: this.handler.state === "idle",
      }).addTo(this.historyGroup);

      marker.trkpt = item;

      // --- ドラッグ終了時の処理 ---
      marker.on("dragend", async (e) => {
        const pos = e.target.getLatLng();
        marker.trkpt.lat = pos.lat;
        marker.trkpt.lon = pos.lng;
        marker.trkpt.extensions.muniCd5 = null;

        try {
          await geoService.resolveAddress(marker.trkpt);
        } catch (err) {
          console.error("足跡移動時の住所解決失敗:", err);
        }

        markerHistory.save(marker.trkpt);
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
          point: marker.trkpt,
        });
        notify("📍 足跡の位置を修正しました");
      });

      // 🔄 共通の MarkerPopup にバインドを委譲
      this.handler.popup.bindPreview(marker);

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
