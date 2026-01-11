import { geoService } from "../components/geo-service.js";
import { markerEvents, MarkerEventTypes } from "./marker-events.js";

export default class MarkerBoundary {
  constructor(handler) {
    this.handler = handler;
    this.show = false;
    this.layer = null;
    this.currentMuniCd5 = null;
  }

  init() {
    // 地図が確定した後にイベントを登録
    this.handler.map.on("moveend", () => {
      if (this.show) this.redraw();
    });
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
    await this.drawBorder({ lat: center.lat, lon: center.lng });
  }

  async drawBorder(coord) {
    const point = await geoService.resolve(coord);
    const newMuniCd5 = point.extensions?.muniCd5;
    if (!newMuniCd5) return;
    if (this.layer && this.currentMuniCd5 === newMuniCd5) return;
    if (this.layer) this.clear();

    const geo = await geoService.fetchBoundary(point);
    if (!geo) return;

    this.layer = L.geoJSON(geo, {
      style: { color: "#ff6600", weight: 3, fill: false },
    }).addTo(this.handler.map);

    this.currentMuniCd5 = newMuniCd5;
  }

  clear() {
    if (this.layer && this.handler.map.hasLayer(this.layer)) {
      this.handler.map.removeLayer(this.layer);
    }
    this.layer = null;
    this.currentMuniCd5 = null;
  }
}