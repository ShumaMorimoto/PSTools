// marker-cluster.js
import { callApi } from "/runapp/lib/js/api.js";

export default class MarkerCluster {
  constructor(handler) {
    this.handler = handler;

    this.show = false;
    this.layers = [];
    this.generation = 0;

    this.useLocal = false; // テスト用
  }

  toggle() {
    this.show = !this.show;
//    this.handler.renumberMarkers();
    this.redraw();
  }

  async redraw() {
    this.markers = this.handler.getMarkers();

    // マーカーが10個未満、または非表示ならクリア
    if (!this.show || this.markers.length < 10) {
      this.clear();
      return;
    }

    this.generation++;
    const gen = this.generation;

    // ★ クラスタリング (APIまたはローカル)
    const clusterIndexList = this.useLocal
      ? this._clusterLocal(this.markers)
      : await this._callExternalClusterAPI(this.markers);

    if (gen !== this.generation) return;

    this.clear();
    this._drawClusters(clusterIndexList); // markerはthis.coreから参照
  }

  clear() {
    this.layers.forEach((l) => this.handler.map.removeLayer(l));
    this.layers = [];
  }

  // --- API呼び出しの修正 ---
  async _callExternalClusterAPI(markers) {
    // API送信用にlat/lonのリストに変換
    const input = markers.map((m) => {
      const ll = m.m.getLatLng(); // entry.m が L.Marker と想定
      return { lat: ll.lat, lon: ll.lng };
    });
    const clusters = await callApi("KMeansCluster", input);
    return clusters;
  }

  // ----------------------------------------
  // ★ 内部クラスタロジック（テスト用）
  // ----------------------------------------
  _clusterLocal(markers) {
    const grid = 0.05;
    const buckets = new Map();

    markers.forEach((entry, idx) => {
      const ll = entry.m.getLatLng();
      const key = `${Math.round(ll.lat / grid)},${Math.round(ll.lng / grid)}`;
      if (!buckets.has(key)) buckets.set(key, []);
      buckets.get(key).push(idx);
    });

    return [...buckets.values()];
  }

  // ----------------------------------------
  // ★ 描画本体（center/radius はここで計算）
  // ----------------------------------------
  // --- 描画ロジックの修正 ---
  _drawClusters(clusterIndexList) {
    clusterIndexList.forEach((indices, i) => {
      if (indices.length === 0) return;

      const color = this._getColor(i);
      const targetMarkers = indices.map((idx) => this.markers[idx]);

      // center / radius 計算をマーカー群から直接行う
      const center = this._computeCenter(targetMarkers);
      const radius = this._computeRadius(center, targetMarkers);

      const circle = L.circle(center, {
        radius,
        color,
        fillColor: color,
        fillOpacity: 0.15,
      }).addTo(this.handler.map);

      this.layers.push(circle);

      // マーカーの色を変更
      targetMarkers.forEach((entry) => {
        entry.m.setIcon(this._coloredIcon(color));
      });
    });
  }

  _computeCenter(markers) {
    let sumLat = 0,
      sumLng = 0;
    markers.forEach((entry) => {
      const ll = entry.m.getLatLng();
      sumLat += ll.lat;
      sumLng += ll.lng;
    });
    return L.latLng(sumLat / markers.length, sumLng / markers.length);
  }

  _computeRadius(center, markers) {
    let maxDist = 0;
    markers.forEach((entry) => {
      const dist = center.distanceTo(entry.m.getLatLng()); // Leaflet標準の計算を利用
      maxDist = Math.max(maxDist, dist);
    });
    return Math.max(150, maxDist * 1.3);
  }

  _getColor(i) {
    const colors = [
      "#e41a1c",
      "#377eb8",
      "#4daf4a",
      "#984ea3",
      "#ff7f00",
      "#ffff33",
      "#a65628",
      "#f781bf",
      "#999999",
      "#66c2a5",
      "#fc8d62",
      "#8da0cb",
      "#e78ac3",
      "#a6d854",
      "#ffd92f",
      "#e5c494",
      "#b3b3b3",
    ];
    //    const colors = ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00"];
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
      "></div>`,
    });
  }
}
