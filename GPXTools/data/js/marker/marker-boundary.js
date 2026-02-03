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

    markerEvents.addEventListener(MarkerEventTypes.POINT_SELECTED, (e) => {
      this._lastPoint = e.detail;
      if (this.show) this.redraw();
    });
  }

  init() {
    // 🚩 境界線を先に、マーカーを後に追加して重なり順を固定
    this.boundaryGroup.addTo(this.handler.map);
  }

  // 🚩 最初のコードで確実だった「DOMレベルの透過制御」を継承
  setInteractive(enabled) {
    const mode = enabled ? "auto" : "none";
    this.handler.preview.historyGroup.eachLayer((marker) => {
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

      this.handler.searchControl.showHistoryByMuni(muniCd);
      
    } catch (e) {
      console.error("Boundary render error:", e);
    }
  }

  _plotLocalHistory(muniCd) {
    const localItems = markerHistory.getByMuniCd(muniCd);
    this.handler.preview.plotMuniHistory(localItems);
  }

  clear() {
    this.boundaryGroup.clearLayers();
    this.handler.preview.historyGroup.clearLayers();
  }
}
