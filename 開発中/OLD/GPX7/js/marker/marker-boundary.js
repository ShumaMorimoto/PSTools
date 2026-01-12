import { geoService } from "../components/geo-service.js";

export default class MarkerBoundary {
  constructor(handler) {
    this.handler = handler;
    this.show = false;
    this.layer = null;

    // 前回描画した自治体コードを保持
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
    // geo-serviceのIFに合わせて {lat, lon} を渡す
    await this.drawBorder({ lat: center.lat, lon: center.lng });
  }

  async drawBorder(coord) {
    // 1. 自治体情報の解決 (lv01Nmなども内部で解決されるが、ここではmuniCd5を使用)
    const point = await geoService.resolve(coord);
    const newMuniCd5 = point.extensions?.muniCd5;

    if (!newMuniCd5) return;

    // 同じ自治体なら何もしない
    if (this.layer && this.currentMuniCd5 === newMuniCd5) {
      return;
    }

    // 別の自治体に移動したなら古いレイヤーを消す
    if (this.layer && this.currentMuniCd5 !== newMuniCd5) {
      this.clear();
    }

    // 2. 境界データの取得 (geoServiceがキャッシュを持っているため高速)
    const geo = await geoService.fetchBoundary(point);
    if (!geo) return;

    // GeoJSON レイヤーを作成して地図に追加
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
    this.currentMuniCd5 = null;
  }
}
