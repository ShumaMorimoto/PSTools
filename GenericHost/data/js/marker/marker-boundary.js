// marker-boundary.js
import { fetchMuniInfo, fetchBoundary } from "./../api-utils.js";

export default class MarkerBoundary {
  constructor(handler) {
    this.handler = handler;
    this.show = false;
    this.layer = null;

    // ★ 前回描画した自治体コードを保持
    this.currentMuniCd5 = null;
  }

  toggle() {
    this.show = !this.show;
    this.redraw();
  }

  async redraw() {
    if (this.show) {
      await this.render();
    } else {
      this.clear();
    }
  }

  async render() {
    const center = this.handler.map.getCenter();
    this.drawBorder(center);
  }

  async drawBorder(m) {
    const muniInfo = await fetchMuniInfo(m.lat, m.lng);
    if (!muniInfo) return;
    const newMuniCd5 = muniInfo.muniCd5;

    if (this.layer && this.currentMuniCd5 === newMuniCd5) {
      return;
    }
    if (this.layer && this.currentMuniCd5 !== newMuniCd5) {
      this.clear();
    }
    const geo = await fetchBoundary(muniInfo);
    if (!geo) return;

    // GeoJSON レイヤーを作成
    this.layer = L.geoJSON(geo, {
      style: {
        color: "#ff6600",
        weight: 3,
        fill: false,
      },
    });

    this.layer.addTo(this.handler.map);
    this.currentMuniCd5 = newMuniCd5;
  }

  clear() {
    if (this.layer && this.handler.map.hasLayer(this.layer)) {
      this.handler.map.removeLayer(this.layer);
    }
    this.layer = null;
    this.currentMuniCd5 = null; // ★ クリア時にリセット
  }
}
