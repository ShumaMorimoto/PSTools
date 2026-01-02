// marker-drag.js
export default class MarkerDrag {
  constructor(selector, handler, core) {
    this.selector = selector;
    this.handler = handler;
    this.core = core;

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
    const nearest = this._findNearestMarker(m, e.latlng);

    if (nearest && nearest.dist < this.REORDER_THRESHOLD) {
      this._highlightReorderTarget(nearest.marker);
      this.selector.map._container.style.cursor = "copy";
    } else {
      this._clearReorderTarget();
      this.selector.map._container.style.cursor = "";
    }
  }
  _onMarkerDragEnd(e, m) {
    const entry = this.core.markers.find((x) => x.m === m);
    const point = entry.point;
    const finalPos = m.getLatLng();
    const nearest = this._findNearestMarker(m, finalPos);
    this._clearReorderTarget();
    // 並び替え
    if (nearest && nearest.dist < this.REORDER_THRESHOLD) {
      this.core.jumpMarker(m, nearest.marker);
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
  // ★ 最近傍マーカー（現在位置で判定）
  // ---------------------------------------------------
  _findNearestMarker(marker, currentLatLng) {
    const pos = this.selector.map.latLngToContainerPoint(currentLatLng);
    let minDist = Infinity;
    let nearest = null;

    this.core.markers.forEach((entry) => {
      if (entry.m === marker) return;

      const p = this.selector.map.latLngToContainerPoint(entry.m.getLatLng());
      const d = pos.distanceTo(p);

      if (d < minDist) {
        minDist = d;
        nearest = { marker: entry.m, dist: d };
      }
    });
    return nearest;
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
