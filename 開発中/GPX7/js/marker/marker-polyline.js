// marker-polyline.js
export default class MarkerPolyline {
  constructor(handler) {
    this.handler = handler;

    this.show = true; // ← フラグはここに持つ
    this.polyline = L.polyline([], { color: "#ff8800", weight: 3 });
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
    const latlngs = this.handler.getMarkers().map(({ m }) => m.getLatLng());
    this.polyline.setLatLngs(latlngs);

    if (!this.handler.map.hasLayer(this.polyline)) {
      this.polyline.addTo(this.handler.map);
    }
  }

  clear() {
    if (this.handler.map.hasLayer(this.polyline)) {
      this.handler.map.removeLayer(this.polyline);
    }
  }
}
