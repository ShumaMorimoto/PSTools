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
    m.on("dragend", (e) => this._onMarkerDragEnd(e, m));
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
  // dragEnd
  // ---------------------------------------------------
  _onMarkerDragEnd(e, m) {
    const entry = this.markers.find((x) => x.m === m);
    if (!entry) return;

    const latlng = e.target.getLatLng();

    entry.point.lat = latlng.lat;
    entry.point.lon = latlng.lng;

    m.setLatLng(latlng);

    this.updateAddress(entry.point);
    this.changeState(MarkerHandler.State.IDLE);
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
