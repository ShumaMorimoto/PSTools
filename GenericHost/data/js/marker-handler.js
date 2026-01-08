// marker-handler.js

import MarkerCore from "./marker/marker-core.js";
import MarkerContextMenu from "./marker/marker-contextmenu.js";
import MarkerDrag from "./marker/marker-drag.js";
import MarkerAddress from "./marker/marker-address.js";
import MarkerPolyline from "./marker/marker-polyline.js";
import MarkerCluster from "./marker/marker-cluster.js";
import MarkerBoundary from "./marker/marker-boundary.js";
import MarkerPreview from "./marker/marker-preview.js";

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
    this.core = new MarkerCore(this);
    this.menu = new MarkerContextMenu(this);
    this.drag = new MarkerDrag(this);
    this.address = new MarkerAddress(this);
    this.polyline = new MarkerPolyline(this);
    this.cluster = new MarkerCluster(this);
    this.boundary = new MarkerBoundary(this);
    this.preview = new MarkerPreview(this);
  }

  // ---------------------------------------------------
  // init
  // ---------------------------------------------------
  init() {
    this.map = this.selector.map;
  }

  setModel(initData) {
    this.core.setModel(initData);
    this.redraw();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // 状態遷移
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;
    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...MarkerHandler.StateInfo[newState],
    });
  }

  redraw() {
    this.polyline.redraw();
    this.cluster.redraw();
    this.boundary.redraw();

    this.selector.coordinatesControl.updateDistance(this.calcTotalDistance());
  }

  calcTotalDistance() {
    const points = this.core.markers.map((x) => x.m.getLatLng());
    if (!points || points.length < 2) return 0;

    let total = 0;
    for (let i = 0; i < points.length - 1; i++) {
      const p1 = points[i];
      const p2 = points[i + 1];
      total += this.map.distance(p1, p2);
    }
    return total;
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
    const entry = this.getEntry(marker);
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
  _addPoint(p) {
    const entry = this.core.addPoint(p);
    if (!p.extensions) {
      this.address.updateAddress(entry.point);
    }
    const marker = entry.m;
    marker.on("click", (e) => this.selector.handleMarkerClick(e, marker));
    this.menu.bindContextMenu(marker);
    this.drag.bindDragEvent(marker);
  }

  addPoint(p) {
    this._addPoint(p);
    this.redraw();
  }

  addPoints(points) {
    points.forEach((p) => {
      this._addPoint(p);
    });
    this.redraw();
  }

  getMarkers() {
    return this.core.markers;
  }

  getMarker(index) {
    return this.core.markers[index].m;
  }

  getNearestMarker(latlng, excludeMarker = null) {
    return this.core.getNearestMarker(latlng,excludeMarker);
  }

  getPoints() {
    return this.core.gpxService.getTrkpts();
  }

  getPoint(index) {
    return this.core.gpxService.getTrkpts()[index];
  }

  getEntry(marker){
     return this.core.getEntry(marker);
  }

  updatePoint(point, info) {
    return this.core.updatePoint(point, info);
  }

  // ---------------------------------------------------
  // clearMarkers
  // ---------------------------------------------------
  clearMarkers() {
    this.core.clearMarkers();
    this.redraw();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // removeMarker
  // ---------------------------------------------------
  removeMarker(m, split = false) {
    this.core.removeMarker(m, split);
    this.redraw();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // jumpMarker
  // ---------------------------------------------------
  jumpMarker(m) {
    this.core.jumpMarker(m);
    this.redraw();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // reorderMarker
  // ---------------------------------------------------
  async reorderMarkers() {
    await this.core.reorderByTSP();
    this.redraw();
  }
  // ---------------------------------------------------
  // 仮マーカー追加 API
  // ---------------------------------------------------
  addPreviewMarker(p) {
    return this.preview.add(p);
  }

  // ---------------------------------------------------
  // ★ Zoom ロジック（idx → marker → zoom）
  // ---------------------------------------------------
  zoomToMarkerByIndex(idx) {
    this.zoomToMarker(this.core.getMarker(idx));
  }
  zoomToMarker(marker) {
    this.map.setView(marker.getLatLng(), 18);
  }
}
