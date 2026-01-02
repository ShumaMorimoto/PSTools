// marker-handler.js (修正後)
import MarkerCore from "./marker/core.js";
import MarkerEvent from "./marker/event.js";

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
    //    this.polylineHandler = new PolylineHandler(selector, this.markerManager);
    this.event = new MarkerEvent(this.core);
    //    this.addressFetcher = new AddressFetcher();
    //    this.contextMenuHandler = new ContextMenuHandler(this.markerManager, this.dragHandler);
  }

  init() {
    const pts = this.gpxService.getTrkpts();
    pts.forEach((tp) => this.addPoint(tp)); // addPointに委譲
    this.changeState(MarkerHandler.State.IDLE);
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
  handleCancel() {}

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


  addPoint(tp) {
    const newTp = this.core.addPoint(tp);
    this.event.bindToMarker(newTp.m); // 修正: addPoint内でmarkerを返すように
    //    this.contextMenuHandler.bindToMarker(newTp.m);
    if (!tp.extensions && !tp.extended) {
      //      this.addressFetcher.updateAddress(tp);
    }
    //    this.polylineHandler.updatePolyline();
    this.changeState(MarkerHandler.State.IDLE);
    return newTp;
  }

  changeState(newState) {
    this.state = newState;
    this.core.renumberMarkers();
    //    this.polylineHandler.updatePolyline();
    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...MarkerHandler.StateInfo[newState],
    });
  }

  // handleMapClick, handleMarkerClick: markerManager.toggleSelectionなどに委譲
  // ...
}
