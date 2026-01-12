// marker-handler.js
import { fetchAddressAsync } from "./api-utils.js";

import MarkerCore from "./marker/marker-core.js";

export default class MarkerHandler {
  static State = {
    IDLE: "idle",
  };

  static StateInfo = {
    idle: { label: "開始", canCancel: false },
  };

  constructor(selector) {
    this.selector = selector;
    this.gpxService = selector.gpxService;
    this.state = MarkerHandler.State.IDLE;
    this.core = new MarkerCore(selector, this.gpxService);

    //    this.markers = [];
    this.requestSeq = 0;

    this.polyline = L.polyline([], { color: "blue", weight: 3 });
    this.REORDER_THRESHOLD = 30; // px距離で判定
    this._draggedIndex = null;
    this._currentReorderTarget = null;
  }

  // ---------------------------------------------------
  // init
  // ---------------------------------------------------
  init() {
    const pts = this.gpxService.getTrkpts();
    pts.forEach((tp) => this.addPoint(tp));
  }

  setModel(initData) {
    this.core.setModel(initData);
  }

  // ---------------------------------------------------
  // 状態遷移
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    this.core.renumberMarkers();
    this._updatePolyline();
    this.debugModel();

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...MarkerHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // mapClick
  // ---------------------------------------------------
  handleMapClick(e) {
    const lat = e.latlng.lat;
    const lng = e.latlng.lng;

    this.addPoint({ lat, lon: lng, muitiRoute: "1" });
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // markerClick
  // ---------------------------------------------------
  handleMarkerClick(e, marker) {
    const entry = this.core.markers.find((x) => x.m === marker);
    if (!entry) return;
    const isMulti = e.originalEvent.shiftKey || e.originalEvent.ctrlKey;
    if (isMulti) {
      entry.selected = !entry.selected;
    } else {
      this.core.markers.forEach((x) => (x.selected = false));
      entry.selected = true;
    }
    this.changeState(MarkerHandler.State.IDLE);
  }

  handleCancel() {}

  // ---------------------------------------------------
  // addPoint
  // ---------------------------------------------------
  addPoint(p) {
    const marker = this.core.addPoint(p);
    if (!p.extensions && !p.extended) {
      this.updateAddress(p);
    }
    this._bindMarkerHandlers(marker);
    this._updatePolyline();
  }

  _bindMarkerHandlers(m) {
    m.on("click", (e) => this.selector.handleMarkerClick(e, m));
    m.on("contextmenu", () => this.removeMarker(m));
    m.on("dragstart", (e) => this._onMarkerDragStart(e, m));
    m.on("drag", (e) => this._onMarkerDrag(e, m));
    m.on("dragend", (e) => this._onMarkerDragEnd(e, m));
  }

  // ---------------------------------------------------
  // clearMarkers
  // ---------------------------------------------------
  clearMarkers() {
    this.core.clearMarkers();
    this._updatePolyline();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // reFetchAllAddresses
  // ---------------------------------------------------
  reFetchAllAddresses() {
    const pts = this.gpxService.getTrkpts();
    pts.forEach((tp) => this.updateAddress(tp));
    //    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // updateAddress
  // ---------------------------------------------------
  updateAddress(point) {
    const entry = this.core.markers.find((e) => e.point === point);
    if (!entry) return;

    const seq = ++this.requestSeq;
    point._reqSeq = seq;

    fetchAddressAsync(point)
      .then((address) => this.applyAddress(point, address, seq))
      .catch((e) => console.warn("住所取得失敗", e));
  }

  applyAddress(point, address, seq) {
    if (point._reqSeq !== seq) return;

    const entry = this.core.markers.find((e) => e.point === point);
    if (!entry) return;

    const marker = entry.m;

    point.name = address.name || "";
    point.desc = address.display_name || "";
    point.extended = address.address || {};

    try {
      marker.bindPopup(point.name || point.desc).openPopup();
    } catch (e) {}

    this.selector.updateList();
  }

  // ---------------------------------------------------
  // ★ Zoom ロジック（idx → marker → zoom）
  // ---------------------------------------------------
  zoomToMarkerByIndex(idx) {
    this.zoomToMarker(this.core.getMarker(idx));
  }

  zoomToMarker(marker) {
    this.selector.map.setView(marker.getLatLng(), 18);
  }

  // ---------------------------------------------------
  // polyline
  // ---------------------------------------------------
  _updatePolyline() {
    const latlngs = this.core.markers.map((entry) => entry.m.getLatLng());
    this.polyline.setLatLngs(latlngs);

    if (!this.selector.map.hasLayer(this.polyline)) {
      this.polyline.addTo(this.selector.map);
    }
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
      this._updatePolyline();
      return;
    }

    // 位置変更
    point.lat = finalPos.lat;
    point.lon = finalPos.lng;
    m.setLatLng(finalPos);

    this._updatePolyline();
    this.updateAddress(point);
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

  // ---------------------------------------------------
  // removeMarker
  // ---------------------------------------------------
  removeMarker(m, split = false) {
    this.core.removeMarker(m, split);
    this._updatePolyline();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // 並び替えセッション API（GA 非依存）
  // ---------------------------------------------------

  // 1. スナップショットを取る
  beginReorderSession() {
    this.core.snapshotMarkers();
    return this.gpxService.getTrkpts(); // モデルを返す（保持はしない）
  }

  // 2. Index を渡して markers を並び替える（Preview）
  applyReorder(indices) {
    this.core.previewReorder(indices);
    this._updatePolyline();
  }

  // 3. 直近の Index を取得する
  getLatestReorderIndices() {
    return this.core._latestIndices;
  }

  // 4. 確定（モデルに Index を適用）
  confirmReorder(indices) {
    this.core.reorderMarkers(indices);
    this._updatePolyline();
  }

  // 5. キャンセル（スナップショットに戻す）
  cancelReorder() {
    this.core.cancelReorder();
    this._updatePolyline();
  }

  debugModel() {
    console.log("GPXModel:", this.gpxService.getModel());
  }
}
