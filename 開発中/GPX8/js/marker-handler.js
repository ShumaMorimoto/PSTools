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
import MarkerIndicator from "./marker/marker-indicator.js";

export default class MarkerHandler {
  static State = {
    IDLE: "idle",
    MARKING: "marking",
  };

  static StateInfo = {
    idle: { label: "開始", canCancel: false },
    marking: { label: "作成終了", canCancel: true },
  };

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
    this.indicator = new MarkerIndicator(this);
  }

  // ---------------------------------------------------
  // init
  // ---------------------------------------------------
  init() {
    this.map = this.selector.map;
    this.boundary.init();
    this.polyline.init();
    if (this.cluster.init) this.cluster.init();

    this.indicator.map = this.map;

    // 1. リストやレイヤー構成が変わった時の再描画
    markerEvents.addEventListener(MarkerEventTypes.LIST_CHANGED, () =>
      this._drawLayers(),
    );

    // 2. ポイント内のデータ（住所・名称・選択状態など）が更新された時
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      // 距離や描画レイヤーの更新
      //      this._drawLayers();

      const { point } = e.detail || {};
      if (!point) return;

      // --- POINTから対応するUI（マーカー）を特定する ---
      // 現時点では本マーカーが対象。今後 preview や indicator も同様に引けるように拡張可能
      const marker = this.getMarkerByPoint(point);

      if (marker) {
        // 内部保持しているポップアップ用データを更新
        this.popup.refresh(marker);

        // 現在ポップアップが表示中なら、DOMの中身を即座に書き換える
        if (marker.isPopupOpen()) {
          const content = this.popup.getContent(marker);
          if (content) {
            marker.setPopupContent(content);
          }
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
    this.core.setModel(initData);
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // 状態遷移
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    // --- 下位コンポーネントのクリック可否を一括制御 ---
    // IDLE時のみ、足跡(Boundary)やしるし(Indicator)を「反応あり」にする
    const isInteractive = newState === MarkerHandler.State.IDLE;

    // Boundary内の全足跡マーカーのクリックを有効/無効化
    this.boundary.setInteractive(isInteractive);
    // Indicator（しるし）自体のクリックを有効/無効化
    this.indicator.setInteractive(isInteractive);

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...MarkerHandler.StateInfo[newState],
    });
  }

  /**
   * 合計距離の計算
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
    if (this.state === MarkerHandler.State.MARKING) {
      this.addPoint({ lat: e.latlng.lat, lon: e.latlng.lng, muitiRoute: "1" });
    } else {
      // 分離したクラスに任せる
      this.indicator.drop(e.latlng);
    }
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
    this.changeState(MarkerHandler.State.IDLE);
  }

  handleCancel() {
    // 仮マーカーを掃除して待機状態へ
    this.preview.clear();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // UI連携アクション (MapSelector側ボタン)
  // ---------------------------------------------------
  onActionButtonClick() {
    if (this.state === MarkerHandler.State.IDLE) {
      this._startMarking();
    } else {
      this._stopMarking();
    }
  }

  _startMarking() {
    this.changeState(MarkerHandler.State.MARKING);
  }

  _stopMarking() {
    this.preview.clear();
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // 地点追加ロジック
  // ---------------------------------------------------
  _addPoint(p) {
    const entry = this.core.addPoint(p, false);

    if (!p.extensions) {
      this.address.updateAddress(entry.point);
    }

    const marker = entry.m;
    marker.on("click", (e) => this.selector.handleMarkerClick(e, marker));

    this.menu.bindMarker(marker);
    this.drag.bindMarker(marker);
    this.popup.bindMarker(marker);

    return entry;
  }

  addPoint(p) {
    // 仮マーカー確定時：仮マーカーを消去
    this.preview.clear();
    const entry = this._addPoint(p);
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
    return entry;
  }

  addPoints(points) {
    if (!points || points.length === 0) return;
    points.forEach((p) => {
      this._addPoint(p);
    });
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  // ---------------------------------------------------
  // 各種操作 (Coreへの委譲)
  // ---------------------------------------------------
  getMarkers() {
    return this.core.markers;
  }

  getMarker(index) {
    const entry = this.core.markers[index];
    if (entry) {
      return entry.m;
    }
    return null;
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
    this.core.clearMarkers();
    this.preview.clear();
    this.changeState(MarkerHandler.State.IDLE);
  }

  removeMarker(m, split = false) {
    this.core.removeMarker(m, split);
    this.changeState(MarkerHandler.State.IDLE);
  }

  jumpMarker(m) {
    // 既存マーカーへのジャンプ
    this.core.jumpMarker(m);
    this.changeState(MarkerHandler.State.IDLE);
  }

  async reorderMarkers() {
    await this.core.reorderByTSP();
  }

  // ---------------------------------------------------
  // UI補助 API (MarkerPreview等から利用)
  // ---------------------------------------------------
  addPreviewMarker(p) {
    // 既存の仮マーカーを掃除
    this.preview.clear();
    // MarkerPreviewのaddを呼び、戻り値を返す
    return this.preview.add(p);
  }

  zoomToMarkerByIndex(idx) {
    const entry = this.core.markers[idx];
    if (entry) {
      this.zoomToMarker(entry.m);
    }
  }

  zoomToMarker(marker) {
    this.map.setView(marker.getLatLng(), 18);
  }
}
