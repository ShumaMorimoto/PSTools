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
    this.core = new MarkerCore(selector, this.gpxService);
    this.menu = new MarkerContextMenu(this, this.core);
    this.drag = new MarkerDrag(selector, this, this.core);
    this.address = new MarkerAddress(this.core);
    this.polyline = new MarkerPolyline(selector, this.core);
    this.cluster = new MarkerCluster(selector, this.core);
    this.boundary = new MarkerBoundary(selector, this.core);
    this.preview = new MarkerPreview(selector, this.core);
  }

  // ---------------------------------------------------
  // init
  // ---------------------------------------------------
  init() {}

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
      total += this.selector.map.distance(p1, p2);
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
    this.selector.map.setView(marker.getLatLng(), 18);
  }
}
