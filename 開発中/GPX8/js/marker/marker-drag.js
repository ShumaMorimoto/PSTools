// marker-drag.js
export default class MarkerDrag {
  constructor(handler) {
    this.handler = handler;
    this.REORDER_THRESHOLD = 30; // px距離で判定
    this._currentReorderTarget = null;
  }

  bindMarker(m) {
    m.on("dragstart", (e) => this._onMarkerDragStart(e, m));
    m.on("drag", (e) => this._onMarkerDrag(e, m));
    m.on("dragend", (e) => this._onMarkerDragEnd(e, m));
  }

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
    if (!entry) return;

    const point = entry.point;
    const finalPos = m.getLatLng();
    const nearest = this.handler.getNearestMarker(finalPos, m);

    this._clearReorderTarget();
    this.handler.map._container.style.cursor = "";

    // --- A. 並び替え（ドロップ先が近い場合） ---
    if (nearest && nearest.dist < this.REORDER_THRESHOLD) {
      // jumpMarker 内部で LIST_CHANGED が発火されるため、これだけで完結
      this.handler.jumpMarker(m, nearest.marker);
      
      // UI上、ドラッグしたマーカーをモデルの元の位置に戻す（リスト順が変わるため）
      m.setLatLng([point.lat, point.lon]); 
      return;
    }

    // --- B. 位置更新（座標移動の場合） ---
    // 直接 point.lat を書き換えず、Core.updatePoint を使うのが「正解」
    this.handler.core.updatePoint(point, {
      lat: finalPos.lat,
      lon: finalPos.lng
    });

    // 住所更新（これ自体も内部で updatePoint を呼ぶので自動連携される）
    this.handler.address.updateAddress(point);
  }

  // --- ハイライト処理 ---
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