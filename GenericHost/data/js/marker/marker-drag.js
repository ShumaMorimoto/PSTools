// marker-drag.js
export default class MarkerDrag {
  constructor(handler) {
    this.handler = handler;
    this.REORDER_THRESHOLD = 30; // px距離で判定
  }

  bindDragEvent(m) {
    m.on("dragstart", (e) => this._onMarkerDragStart(e, m));
    m.on("drag", (e) => this._onMarkerDrag(e, m));
    m.on("dragend", (e) => this._onMarkerDragEnd(e, m));
  }

  // ---------------------------------------------------
  // ★ dragstart
  // ---------------------------------------------------
  _onMarkerDragStart(e, m) {}
  _onMarkerDrag(e, m) {
    const nearest = this.handler.getNearestMarker(e.latlng, m);

    if (nearest && nearest.dist < this.REORDER_THRESHOLD) {
      this._highlightReorderTarget(nearest.marker);
      this.handler.map._container.style.cursor = "copy";
    } else {
      this._clearReorderTarget();
      this.handler.map._container.style.cursor = "";
    }
  }
  _onMarkerDragEnd(e, m) {
    const entry = this.handler.getEntry(m);
    const point = entry.point;
    const finalPos = m.getLatLng();
    const nearest = this.handler.getNearestMarker(finalPos, m);
    this._clearReorderTarget();
    // 並び替え
    if (nearest && nearest.dist < this.REORDER_THRESHOLD) {
      this.handler.jumpMarker(m, nearest.marker);
      m.setLatLng([point.lat, point.lon]); // UI を元に戻す
      this.handler.redraw();
      return;
    }
    // 位置変更
    point.lat = finalPos.lat;
    point.lon = finalPos.lng;
    m.setLatLng(finalPos);

    this.handler.redraw();
    this.handler.address.updateAddress(point);
  }

  // ---------------------------------------------------
  // ★ ハイライト
  // ---------------------------------------------------
  _highlightReorderTarget(marker) {
    if (this._currentReorderTarget === marker) return;

    this._clearReorderTarget();
    this._currentReorderTarget = marker;

    const el = marker._icon;
    if (el) el.classList.add("reorder-target");
  }

  _clearReorderTarget() {
    if (!this._currentReorderTarget) return;

    const el = this._currentReorderTarget._icon;
    if (el) el.classList.remove("reorder-target");

    this._currentReorderTarget = null;
  }
}
