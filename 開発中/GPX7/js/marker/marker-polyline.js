// marker-polyline.js
export default class MarkerPolyline {
  constructor(selector, core) {
    this.selector = selector;
    this.core = core;

    this.show = true; // ← フラグはここに持つ
    this.polyline = L.polyline([], { color: "blue", weight: 3 });
  }

  toggle() {
    this.show = !this.show;
    this.redraw();
  }

  redraw() {
    if (this.show) {
      this.render();
    } else {
      this.clear();
    }
  }

  render() {
    const latlngs = this.core.markers.map((entry) => entry.m.getLatLng());
    this.polyline.setLatLngs(latlngs);

    if (!this.selector.map.hasLayer(this.polyline)) {
      this.polyline.addTo(this.selector.map);
    }
  }

  clear() {
    if (this.selector.map.hasLayer(this.polyline)) {
      this.selector.map.removeLayer(this.polyline);
    }
  }
}
