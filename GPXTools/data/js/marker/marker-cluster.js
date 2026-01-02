// marker-cluster.js
import { callApi } from "/runapp/lib/js/api.js";

export default class MarkerCluster {
  constructor(selector, core) {
    this.selector = selector;
    this.core = core;

    this.show = false;
    this.layers = [];
    this.generation = 0;

    this.useLocal = false; // テスト用
  }

  toggle() {
    this.show = !this.show;
    this.redraw();
  }

  async redraw() {
    if (!this.show) {
      this.clear();
      return;
    }

    this.generation++;
    const gen = this.generation;

    const points = this.core.markers.map(e => ({
      lat: e.point.lat,
      lon: e.point.lon
    }));

    // ★ 外部 or ローカル切り替え
    const clusterIndexList = this.useLocal
      ? this._clusterLocal(points)           // number[][]
      : await this._callExternalClusterAPI(points); // number[][]

    // ★ モデルが変わっていたら破棄
    if (gen !== this.generation) return;

    this.clear();
    this._drawClusters(clusterIndexList, points);
  }

  clear() {
    this.layers.forEach(l => this.selector.map.removeLayer(l));
    this.layers = [];
  }

  // ----------------------------------------
  // ★ 外部クラスタリングAPI（本番）
  // ----------------------------------------
  async _callExternalClusterAPI(points) {
    const input = points.map(p => ({ lat: p.lat, lon: p.lon }));
    const clusters = await callApi("Cluster", input);

    // clusters は number[][] の前提
    return clusters;
  }

  // ----------------------------------------
  // ★ 内部クラスタロジック（テスト用）
  // ----------------------------------------
  _clusterLocal(points) {
    const grid = 0.05;
    const buckets = new Map();

    points.forEach((p, idx) => {
      const key = `${Math.round(p.lat / grid)},${Math.round(p.lon / grid)}`;
      if (!buckets.has(key)) buckets.set(key, []);
      buckets.get(key).push(idx);
    });

    return [...buckets.values()]; // number[][]
  }

  // ----------------------------------------
  // ★ 描画本体（center/radius はここで計算）
  // ----------------------------------------
  _drawClusters(clusterIndexList, points) {
    clusterIndexList.forEach((indices, i) => {
      if (indices.length === 0) return;

      const color = this._getColor(i);

      // --- center 計算 ---
      const center = this._computeCenter(indices, points);

      // --- radius 計算 ---
      const radius = this._computeRadius(center, indices, points);

      // --- 円 ---
      const circle = L.circle(center, {
        radius,
        color,
        fillColor: color,
        fillOpacity: 0.15
      }).addTo(this.selector.map);

      this.layers.push(circle);

      // --- マーカー色変更 ---
      indices.forEach(idx => {
        const entry = this.core.markers[idx];
        entry.m.setIcon(this._coloredIcon(color));
      });
    });
  }

  _computeCenter(indices, points) {
    let sumLat = 0, sumLon = 0;
    indices.forEach(idx => {
      sumLat += points[idx].lat;
      sumLon += points[idx].lon;
    });
    return {
      lat: sumLat / indices.length,
      lon: sumLon / indices.length
    };
  }

  _computeRadius(center, indices, points) {
    const R = 6371000;
    const toRad = d => d * Math.PI / 180;

    let maxDist = 0;

    indices.forEach(idx => {
      const p = points[idx];
      const dLat = toRad(p.lat - center.lat);
      const dLon = toRad(p.lon - center.lon);
      const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(center.lat)) *
          Math.cos(toRad(p.lat)) *
          Math.sin(dLon / 2) ** 2;
      const dist = 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      maxDist = Math.max(maxDist, dist);
    });

    return Math.max(150, maxDist * 1.3);
  }

  _getColor(i) {
    const colors = ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00"];
    return colors[i % colors.length];
  }

  _coloredIcon(color) {
    return L.divIcon({
      html: `<div style="
        width: 14px;
        height: 14px;
        border-radius: 50%;
        border: 2px solid #fff;
        background: ${color};
      "></div>`
    });
  }
}