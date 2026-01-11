import { callApi } from "/lib/js/api.js";
import { markerEvents, MarkerEventTypes } from "./marker-events.js";

export default class MarkerCluster {
  constructor(handler) {
    this.handler = handler;
    this.show = false;
    this.layers = [];
    this.generation = 0;
    this.useLocal = false;

    markerEvents.addEventListener(MarkerEventTypes.LIST_CHANGED, () => {
      if (this.show) this.redraw();
    });
  }

  init() {
    // 地図依存の初期化が必要な場合はここに記述
  }

  toggle() {
    this.show = !this.show;
    if (!this.show) {
      this.clear();
      this.handler.core.renumberMarkers(); 
    } else {
      this.redraw();
    }
  }

  async redraw() {
    this.markers = this.handler.getMarkers();
    if (!this.show || this.markers.length < 10) {
      this.clear();
      this.handler.core.renumberMarkers();
      return;
    }

    this.generation++;
    const gen = this.generation;
    const clusterIndexList = this.useLocal
      ? this._clusterLocal(this.markers)
      : await this._callExternalClusterAPI(this.markers);

    if (gen !== this.generation) return;
    this.clear();
    this._drawClusters(clusterIndexList);
  }

  clear() {
    this.layers.forEach((l) => this.handler.map.removeLayer(l));
    this.layers = [];
  }

  _drawClusters(clusterIndexList) {
    clusterIndexList.forEach((indices, i) => {
      if (indices.length === 0) return;
      const color = this._getColor(i);
      const targetMarkers = indices.map((idx) => this.markers[idx]);
      const center = this._computeCenter(targetMarkers);
      const radius = this._computeRadius(center, targetMarkers);

      const circle = L.circle(center, {
        radius, color, fillColor: color, fillOpacity: 0.15,
      }).addTo(this.handler.map);
      this.layers.push(circle);

      targetMarkers.forEach((entry) => {
        entry.m.setIcon(this._coloredIcon(color));
      });
    });
  }

  async _callExternalClusterAPI(markers) {
    const input = markers.map((m) => {
      const ll = m.m.getLatLng();
      return { lat: ll.lat, lon: ll.lng };
    });
    return await callApi("KMeansCluster", input);
  }

  _computeCenter(markers) {
    let sumLat = 0, sumLng = 0;
    markers.forEach((e) => {
      const ll = e.m.getLatLng();
      sumLat += ll.lat; sumLng += ll.lng;
    });
    return L.latLng(sumLat / markers.length, sumLng / markers.length);
  }

  _computeRadius(center, markers) {
    let maxDist = 0;
    markers.forEach((e) => {
      maxDist = Math.max(maxDist, center.distanceTo(e.m.getLatLng()));
    });
    return Math.max(150, maxDist * 1.3);
  }

  _getColor(i) {
    const colors = ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00", "#ffff33", "#a65628"];
    return colors[i % colors.length];
  }

  _coloredIcon(color) {
    return L.divIcon({
      html: `<div style="width: 14px; height: 14px; border-radius: 50%; border: 2px solid #fff; background: ${color};"></div>`,
    });
  }

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
}