import {
  markerEvents,
  MarkerEventTypes,
  dispatchMarkerEvent,
} from "./marker/marker-events.js";
import MarkerCore from "./marker/marker-core.js";
import MarkerContextMenu from "./marker/marker-contextmenu.js";
import MarkerDrag from "./marker/marker-drag.js";
import MarkerPopup from "./marker/marker-popup.js";
import MarkerAddress from "./marker/marker-address.js";
import MarkerPolyline from "./marker/marker-polyline.js";
import MarkerCluster from "./marker/marker-cluster.js";
import MarkerBoundary from "./marker/marker-boundary.js";
import MarkerPreview from "./marker/marker-preview.js";

export default class MarkerHandler {
  static State = { IDLE: "idle" };
  static StateInfo = { idle: { label: "開始", canCancel: false } };

  constructor(selector) {
    this.selector = selector;
    this.gpxService = selector.gpxService;
    this.state = MarkerHandler.State.IDLE;

    // 各コンポーネントの初期化
    this.core = new MarkerCore(this);
    this.menu = new MarkerContextMenu(this);
    this.drag = new MarkerDrag(this);
    this.popup = new MarkerPopup(this);
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
    this.boundary.init();
    this.polyline.init();
    if (this.cluster.init) this.cluster.init();

    // 共通イベント監視
    markerEvents.addEventListener(MarkerEventTypes.LIST_CHANGED, () =>
      this._drawLayers()
    );
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      this._drawLayers();

      const { entry } = e.detail || {};
      if (entry && entry.m) {
        // メモリ上の設定を更新
        this.popup.refresh(entry.m);
        // 開いている場合は中身を動的に差し替え
        if (entry.m.isPopupOpen()) {
          const content = this.popup.getContent(entry.m);
          if (content) entry.m.setPopupContent(content);
        }
      }
    });
  }

  /**
   * 地図上の描画（ポリライン・クラスタ・境界線）を最新状態にする
   */
  _drawLayers() {
    this.polyline.redraw();
    this.cluster.redraw();
    this.boundary.redraw();
  }

  // ---------------------------------------------------
  // モデル操作
  // ---------------------------------------------------
  setModel(initData) {
    // core.setModel 内部で addPoints を呼び、LIST_CHANGED が発火するため
    // 自動的に _drawLayers() と UI側の更新が走ります
    this.core.setModel(initData);
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

  /**
   * 合計距離の計算（MapInitializer側の接着剤から呼ばれる）
   */
  calcTotalDistance() {
    const points = this.core.markers.map((x) => x.m.getLatLng());
    if (!points || points.length < 2) return 0;
    let total = 0;
    for (let i = 0; i < points.length - 1; i++) {
      total += this.map.distance(points[i], points[i + 1]);
    }
    return total;
  }

  // ---------------------------------------------------
  // 地図イベントハンドラ
  // ---------------------------------------------------
  handleMapClick(e) {
    // muitiRoute: "1" を付与（オリジナルの仕様）
    this.addPoint({ lat: e.latlng.lat, lon: e.latlng.lng, muitiRoute: "1" });
    this.changeState(MarkerHandler.State.IDLE);
  }

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

    // 選択状態の変更を通知（UI側がこれを受けてリストの強調表示などを更新する）
    dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { entry });
    this.changeState(MarkerHandler.State.IDLE);
  }

  handleCancel() {}

  // ---------------------------------------------------
  // 地点追加ロジック
  // ---------------------------------------------------
  _addPoint(p) {
    // Core側でマーカー生成とGPXデータ追加。
    // 引数 false は Core 内での即時イベント発火を抑止（一括追加のため）
    const entry = this.core.addPoint(p, false);

    // 住所がない場合は非同期で取得
    if (!p.extensions) {
      this.address.updateAddress(entry.point);
    }

    const marker = entry.m;
    // 地図上のマーカークリックイベントを Selector（モード管理）に飛ばす
    marker.on("click", (e) => this.selector.handleMarkerClick(e, marker));

    // 右クリックメニューとドラッグのバインド
    this.menu.bindMarker(marker);
    this.drag.bindMarker(marker);
    this.popup.bindMarker(marker);

    return entry;
  }

  addPoint(p) {
    this._addPoint(p);
    // 1件追加時は即座に通知
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  addPoints(points) {
    if (!points || points.length === 0) return;
    points.forEach((p) => {
      this._addPoint(p);
    });
    // 全件追加後に一括で通知（描画負荷を軽減）
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  // ---------------------------------------------------
  // 各種操作 (Coreへの委譲と状態管理)
  // ---------------------------------------------------
  getMarkers() {
    return this.core.markers;
  }
  getMarker(index) {
    return this.core.markers[index].m;
  }
  getNearestMarker(latlng, ex = null) {
    return this.core.getNearestMarker(latlng, ex);
  }
  getPoints() {
    return this.gpxService.getTrkpts();
  }
  getPoint(index) {
    return this.gpxService.getTrkpts()[index];
  }
  getEntry(marker) {
    return this.core.getEntry(marker);
  }
  getMarkerByPoint(point) {
    return this.core.getMarkerByPoint(point);
  }

  updatePoint(point, info) {
    return this.core.updatePoint(point, info);
  }

  clearMarkers() {
    this.core.clearMarkers(); // Core内で LIST_CHANGED が飛ぶ
    this.changeState(MarkerHandler.State.IDLE);
  }

  removeMarker(m, split = false) {
    this.core.removeMarker(m, split); // Core内で LIST_CHANGED が飛ぶ
    this.changeState(MarkerHandler.State.IDLE);
  }

  jumpMarker(m) {
    this.core.jumpMarker(m); // Core内で LIST_CHANGED が飛ぶ
    this.changeState(MarkerHandler.State.IDLE);
  }

  async reorderMarkers() {
    await this.core.reorderByTSP(); // Core内で LIST_CHANGED が飛ぶ
  }

  // ---------------------------------------------------
  // UI補助 API
  // ---------------------------------------------------
  addPreviewMarker(p) {
    return this.preview.add(p);
  }

  zoomToMarkerByIndex(idx) {
    const entry = this.core.markers[idx];
    if (entry) this.zoomToMarker(entry.m);
  }

  zoomToMarker(marker) {
    this.map.setView(marker.getLatLng(), 18);
  }
}
