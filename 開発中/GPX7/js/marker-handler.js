// marker-handler.js

import MarkerCore from "./marker/marker-core.js";
import MarkerContextMenu from "./marker/marker-contextmenu.js";
import MarkerDrag from "./marker/marker-drag.js";
import MarkerAddress from "./marker/marker-address.js";
import MarkerPolyline from "./marker/marker-polyline.js";
import MarkerCluster from "./marker/marker-cluster.js";

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
    const entry = this.core.addPoint(p);
    if (!p.extensions) {
      this.address.updateAddress(entry.point);
    }
    const marker = entry.m;
    marker.on("click", (e) => this.selector.handleMarkerClick(e, marker));
    this.menu.bindContextMenu(marker);
    this.drag.bindDragEvent(marker);

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

  //
  // 仮マーカ
  //
  showPreviewMarker(geocode) {
    const center = geocode.center;
    const keyword = geocode.name;

    // 既存の仮マーカーがあれば削除
    if (this.previewMarker) {
      this.selector.map.removeLayer(this.previewMarker);
    }

    const btnId = "confirm-" + Date.now();

    // ★★★ draggable: true を追加 ★★★
    this.previewMarker = L.marker(center, { draggable: true }).addTo(
      this.selector.map
    );

    // Popup
    this.previewMarker.bindPopup(`
      <strong>仮マーカー</strong><br>
      Keyword: ${keyword}<br>
      <button id="${btnId}">この地点を登録</button>
  `);

    // ズーム（あなたの設計では MarkerHandler の責務）
    this.selector.map.setView(center, 16);

    // Popup を開く
    setTimeout(() => this.previewMarker.openPopup(), 50);

    // ★★★ ドラッグ後の位置更新 ★★★
    this.previewMarker.on("dragend", (e) => {
      const newPos = e.target.getLatLng();
      this.previewMarker.setLatLng(newPos); // 念のため再セット
    });

    // 登録ボタン
    this.previewMarker.on("popupopen", () => {
      document.getElementById(btnId).onclick = () => {
        const pos = this.previewMarker.getLatLng();
        this.confirmPreviewMarker(pos, keyword);
      };
    });
  }
  confirmPreviewMarker(center, keyword) {
    this.addPoint({
      lat: center.lat,
      lon: center.lng,
      extensions: { keyword },
    });

    this.selector.map.removeLayer(this.previewMarker);
    this.previewMarker = null;
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
  // 並び替えセッション API（GA 非依存）
  // ---------------------------------------------------

  // 1. スナップショットを取る
  beginReorderSession() {
    return this.core.snapshotMarkers();
  }
  // 2. Index を渡して markers を並び替える（Preview）
  applyReorder(indices) {
    this.core.previewReorder(indices);
    this.redraw();
  }
  // 3. 直近の Index を取得する
  getLatestReorderIndices() {
    return this.core._latestIndices;
  }
  // 4. 確定（モデルに Index を適用）
  confirmReorder(indices) {
    this.core.reorderMarkers(indices);
    this.redraw();
  }
  // 5. キャンセル（スナップショットに戻す）
  cancelReorder() {
    this.core.cancelReorder();
    this.redraw();
  }
}
