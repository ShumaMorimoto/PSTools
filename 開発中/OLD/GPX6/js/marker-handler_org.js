// marker-handler.js
import { fetchAddressAsync } from "./api-utils.js";

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
    this.markers = [];
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

  // ---------------------------------------------------
  // 状態遷移
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    this.renumberMarkers();
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

    const tp = this.gpxService.appendTrkpt({ lat, lon: lng, muitiRoute: "1" });
    this.addPoint(tp);

    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // markerClick
  // ---------------------------------------------------
  handleMarkerClick(e, marker) {
    const entry = this.markers.find((x) => x.m === marker);
    if (!entry) return;
    const isMulti = e.originalEvent.shiftKey || e.originalEvent.ctrlKey;
    if (isMulti) {
      entry.selected = !entry.selected;
    } else {
      this.markers.forEach((x) => (x.selected = false));
      entry.selected = true;
    }
    this.changeState(MarkerHandler.State.IDLE);
  }

  handleCancel() {}

  // ---------------------------------------------------
  // addPoint
  // ---------------------------------------------------
  addPoint(tp) {
    const marker = this._buildMarkerInstance(tp);
    this.markers.push({ m: marker, point: tp, selected: false });
    marker.addTo(this.selector.map);
    if (!tp.extensions && !tp.extended) {
      this.updateAddress(tp);
    }
    this._bindMarkerHandlers(marker);
    this.changeState(MarkerHandler.State.IDLE);
    return tp;
  }

  _buildMarkerInstance(tp) {
    const icon = L.ExtraMarkers.icon({
      icon: "fa-number",
      number: 0,
      markerColor: "blue",
      shape: "circle",
    });
    const m = L.marker([tp.lat, tp.lon], {
      draggable: true,
      icon: icon,
    });

    if (tp.name || tp.desc) {
      m.bindPopup(tp.name || tp.desc);
    }
    return m;
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
    const pts = this.gpxService.getTrkpts();
    pts.length = 0;
    this.markers.forEach((entry) => {
      this.selector.map.removeLayer(entry.m);
    });
    this.markers = [];
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
  // renumberMarkers
  // ---------------------------------------------------
  renumberMarkers() {
    this.markers.forEach((entry, i) => {
      const icon = L.ExtraMarkers.icon({
        icon: "fa-number",
        number: i + 1,
        markerColor: entry.selected ? "red" : "blue",
        shape: "circle",
      });
      entry.m.setIcon(icon);
    });
  }
  // ---------------------------------------------------
  // updateAddress
  // ---------------------------------------------------
  updateAddress(point) {
    const entry = this.markers.find((e) => e.point === point);
    if (!entry) return;

    const seq = ++this.requestSeq;
    point._reqSeq = seq;

    fetchAddressAsync(point)
      .then((address) => this.applyAddress(point, address, seq))
      .catch((e) => console.warn("住所取得失敗", e));
  }

  applyAddress(point, address, seq) {
    if (point._reqSeq !== seq) return;

    const entry = this.markers.find((e) => e.point === point);
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
    const entry = this.markers[idx];
    if (!entry) return;
    this.zoomToMarker(entry.m);
  }

  zoomToMarker(marker) {
    this.selector.map.setView(marker.getLatLng(), 18);
  }

  // ---------------------------------------------------
  // polyline
  // ---------------------------------------------------
  _updatePolyline() {
    const latlngs = this.markers.map((entry) => entry.m.getLatLng());
    this.polyline.setLatLngs(latlngs);

    if (!this.selector.map.hasLayer(this.polyline)) {
      this.polyline.addTo(this.selector.map);
    }
  }

  // ---------------------------------------------------
  // ★ dragstart
  // ---------------------------------------------------
  _onMarkerDragStart(e, m) {
    const entry = this.markers.find((x) => x.m === m);
    if (!entry) return;

    this._draggedIndex = this.markers.indexOf(entry);
    this._originalLatLng = m.getLatLng(); // Store original position
  }

  // ---------------------------------------------------
  // ★ drag（現在位置で距離判定）
  // ---------------------------------------------------
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

  // ---------------------------------------------------
  // ★ dragend（並び替え or 位置変更）
  // ---------------------------------------------------
  _onMarkerDragEnd(e, m) {
    const entry = this.markers.find((x) => x.m === m);
    if (!entry) return;

    const finalPos = e.target.getLatLng();

    const nearest = this._findNearestMarker(m, finalPos);
    const draggedIndex = this._draggedIndex;

    this.selector.map._container.style.cursor = "";
    this._clearReorderTarget();
    this._draggedIndex = null;

    // 並び替え確定
    if (nearest && nearest.dist < this.REORDER_THRESHOLD) {
      const targetIndex = nearest.index;

      if (targetIndex !== draggedIndex) {
        const indices = this._buildReorderIndices(draggedIndex, targetIndex);
        this._applyReorder(indices);
        // 元の位置に戻す
        m.setLatLng(this._originalLatLng);
        this.changeState(MarkerHandler.State.IDLE);
        return;
      }
    }

    // 位置変更
    entry.point.lat = finalPos.lat;
    entry.point.lon = finalPos.lng;
    m.setLatLng(finalPos);

    this.updateAddress(entry.point);
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // ★ 最近傍マーカー（現在位置で判定）
  // ---------------------------------------------------
  _findNearestMarker(marker, currentLatLng) {
    const pos = this.selector.map.latLngToContainerPoint(currentLatLng);
    let minDist = Infinity;
    let nearest = null;

    this.markers.forEach((entry, i) => {
      if (entry.m === marker) return;

      const p = this.selector.map.latLngToContainerPoint(entry.m.getLatLng());
      const d = pos.distanceTo(p);

      if (d < minDist) {
        minDist = d;
        nearest = { marker: entry.m, index: i, dist: d };
      }
    });

    return nearest;
  }

  // ---------------------------------------------------
  // ★ 並び替え index 生成
  // ---------------------------------------------------
  _buildReorderIndices(draggedIndex, targetIndex) {
    const count = this.markers.length;
    const indices = [...Array(count).keys()];

    const dragged = indices.splice(draggedIndex, 1)[0];
    indices.splice(targetIndex + 1, 0, dragged);

    return indices;
  }

  // ---------------------------------------------------
  // ★ 並び替え適用
  // ---------------------------------------------------
  _applyReorder(indices) {
    const newMarkers = indices.map((i) => this.markers[i]);
    this.markers.length = 0;
    this.markers.push(...newMarkers);

    // Update GPX points order
    const pts = this.gpxService.getTrkpts();
    const newPts = indices.map((i) => pts[i]);
    pts.length = 0;
    pts.push(...newPts);

    this.renumberMarkers();
    this._updatePolyline();
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
    const idx = this.markers.findIndex((e) => e.m === m);
    if (idx === -1) return;

    const toRemove = split
      ? this.markers.slice(0, idx + 1)
      : this.markers.slice(idx, idx + 1);

    toRemove.forEach((entry) => {
      this.gpxService.removeTrkpt(entry.point);
      this.selector.map.removeLayer(entry.m);
    });

    this.markers = this.markers.filter((e) => !toRemove.includes(e));

    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // 並び替えセッション API（GA 非依存）
  // ---------------------------------------------------

  // 1. スナップショットを取る
  beginReorderSession() {
    this._snapshotMarkers = [...this.markers]; // markers の順序スナップショット
    this._latestIndices = null; // 最新 index を保持する領域
    return this.gpxService.getTrkpts(); // モデルを返す（保持はしない）
  }

  // 2. Index を渡して markers を並び替える（Preview）
  applyReorder(indices) {
    if (!this._snapshotMarkers) return;

    this._latestIndices = indices; // 最新 index を保持
    this.markers = indices.map((i) => this._snapshotMarkers[i]);

    this.renumberMarkers();
    this._updatePolyline();
    this.selector.updateList();
  }

  // 3. 直近の Index を取得する
  getLatestReorderIndices() {
    return this._latestIndices;
  }

  // 4. 確定（モデルに Index を適用）
  confirmReorder(indices) {
    const trkpts = this.gpxService.getTrkpts();
    const newTrkpts = indices.map((i) => trkpts[i]);
    this.gpxService.setTrkpts(newTrkpts);

    // markers は Preview の並びがそのまま正しい
    this._snapshotMarkers = null;
    this._latestIndices = null;

    this.renumberMarkers();
    this._updatePolyline();
    this.selector.updateList();
  }

  // 5. キャンセル（スナップショットに戻す）
  cancelReorder() {
    if (!this._snapshotMarkers) return;

    this.markers = [...this._snapshotMarkers];

    this._snapshotMarkers = null;
    this._latestIndices = null;

    this.renumberMarkers();
    this._updatePolyline();
    this.selector.updateList();
  }

  debugModel() {
    console.log("GPXModel:", this.gpxService.getModel());
  }
}
