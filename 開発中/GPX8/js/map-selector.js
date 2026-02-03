// map-selector.js
import GPXService from "./gpx-service.js";
import MapInitializer from "./map-initializer.js";
import MarkerHandler from "./marker-handler.js";
import ImageHandler from "./image-handler.js";
import { markerHistory } from "./marker/marker-history.js";
import TownHandler from "./town-handler.js";
import AreaHandler from "./area-handler.js";
import UIManager from "./ui-manager.js";
import { initToast } from "./api-utils.js";

export default class MapSelector {
  static Mode = {
    DEFAULT: "default",
    IMAGE_MODE: "imageMode",
    TOWN_MODE: "townMode",
    AREA_MODE: "areaMode",
  };

  static ModeConfig = {
    [MapSelector.Mode.DEFAULT]: {
      buttonId: "addMarker",
      handlerClass: MarkerHandler,
    },
    [MapSelector.Mode.IMAGE_MODE]: {
      buttonId: "addImage",
      handlerClass: ImageHandler,
    },
    [MapSelector.Mode.TOWN_MODE]: {
      buttonId: "addTown",
      handlerClass: TownHandler,
    },
    [MapSelector.Mode.AREA_MODE]: {
      buttonId: "addArea",
      handlerClass: AreaHandler,
    },
  };

  constructor(options) {
    this.mapId = options.mapId;
    this.controls = options.controls;
    this.initialView = options.initialView || [35.6895, 139.6917, 12];

    this.map = null;
    this.imgGroup = null;

    this.currentMode = MapSelector.Mode.DEFAULT;
    this.currentHandler = null;

    this.gpxService = new GPXService();

    // ModeConfig に基づいて全 Handler インスタンスを一括生成
    this.handlers = {};
    Object.entries(MapSelector.ModeConfig).forEach(([mode, cfg]) => {
      this.handlers[mode] = new cfg.handlerClass(this);
    });

    this.uiManager = new UIManager(this);
    this.mapInitializer = new MapInitializer(this);
  }

  // ---------------------------------------------------
  // 初期化シーケンス
  // ---------------------------------------------------
  async init(initData) {
    // 1. まず地図（L.map）とボタンの「器」を作る
    this.mapInitializer.initMap();
    this.uiManager.initUIHandlers();

    // 2. 各ハンドラの初期化（レイヤー準備など、中身を動作可能にする）
    Object.values(this.handlers).forEach((h) => h.init?.());

    // 3. すべての準備が整ってから「ボタンの配線（onClick）」を行う ★二重登録防止
    this.mapInitializer.setupEventHandlers();

    // 4. ライフサイクル・外部連携の設定
    window.addEventListener("beforeunload", () => {
      try {
        navigator.sendBeacon("/done");
      } catch (e) {}
    });

    // 初期状態の設定
    this.currentHandler = this.handlers[MapSelector.Mode.DEFAULT];
    this.uiManager.updateModeButtons(this.currentMode);

    // 検索結果選択時のプレビュー処理をバインド
    if (this.searchControl) {
      this.searchControl._markerHistory = markerHistory;
      this.searchControl.bindOnLocationSelected(
        this.handlers[MapSelector.Mode.DEFAULT].preview.onSelected,
      );
    }

    // Toast通知の初期化
    initToast(document.getElementById(this.controls.toastId));

// --- ★追加: 履歴から最新の座標を取得して地図を移動 ---
    this._setInitialViewFromHistory();

//    // 初期データがあればロード
//    if (initData) {
//      this.handlers[MapSelector.Mode.DEFAULT].setModel(initData);
//    }
  }

  /**
   * 履歴の最新データに基づいて初期表示位置を調整する
   */
  _setInitialViewFromHistory() {
    const history = markerHistory.getAll();
    if (history && history.length > 0) {
      const latest = history[0]; // 保存時に unshift しているので [0] が最新
      if (latest.lat && latest.lon) {
        // ズームレベルは初期設定(12など)を維持するか、少し寄る(15など)
        const zoom = this.initialView[2] || 15;
        this.map.setView([latest.lat, latest.lon], zoom);
      }
    }
  }

  // ---------------------------------------------------
  // 表示切替
  // ---------------------------------------------------
  handleTogglePolyline(state) {
    this.handlers[MapSelector.Mode.DEFAULT].polyline.toggle(state);
  }

  handleToggleCluster(state) {
    this.handlers[MapSelector.Mode.DEFAULT].cluster.toggle(state);
  }

  handleToggleBoundary(state) {
    this.handlers[MapSelector.Mode.DEFAULT].boundary.toggle(state);
  }

  // ---------------------------------------------------
  // モード制御
  // ---------------------------------------------------
  setMode(mode) {
    this.currentMode = mode;
    this.currentHandler =
      this.handlers[mode] || this.handlers[MapSelector.Mode.DEFAULT];
    this.uiManager.updateModeButtons(mode);
  }

  /**
   * Handler からの状態変更通知（UI/CSSクラスの更新）
   */
  onHandlerStateChanged({ state, canCancel }) {
    const config = MapSelector.ModeConfig[this.currentMode];
    if (config && config.buttonId) {
      this.uiManager.updateStateUI({
        buttonId: config.buttonId,
        state,
        canCancel,
      });
    }
  }

  // ---------------------------------------------------
  // 地図・マーカーイベントの中継
  // ---------------------------------------------------
  handleCancel() {
    this.currentHandler.handleCancel?.();
  }

  handleMapClick(e) {
    this.currentHandler.handleMapClick?.(e);
  }

  handleMarkerClick(e, marker) {
    this.currentHandler.handleMarkerClick?.(e, marker);
  }

  // ---------------------------------------------------
  // GPX操作の中継
  // ---------------------------------------------------
  handleGpxLoad(file) {
    this.uiManager.handleGpxLoad(file);
  }

  handleGpxSave() {
    this.uiManager.handleGpxSave();
  }

  // ===================================================
  // Facade API (MarkerHandler.default へのショートカット)
  // ===================================================
  addPoint(p) {
    this.handlers[MapSelector.Mode.DEFAULT].addPoint(p);
  }
  addPoints(pts) {
    this.handlers[MapSelector.Mode.DEFAULT].addPoints(pts);
  }
  removeMarker(marker, split = false) {
    this.handlers[MapSelector.Mode.DEFAULT].removeMarker(marker, split);
  }
  clearMarkers() {
    this.handlers[MapSelector.Mode.DEFAULT].clearMarkers();
  }
  zoomToMarkerByIndex(idx) {
    this.handlers[MapSelector.Mode.DEFAULT].zoomToMarkerByIndex(idx);
  }
  updateAddress(m) {
    this.handlers[MapSelector.Mode.DEFAULT].address.updateAddress(m);
  }
  reFetchAllAddresses() {
    this.handlers[MapSelector.Mode.DEFAULT].address.reFetchAllAddresses();
  }
  reorderMarkers() {
    this.handlers[MapSelector.Mode.DEFAULT].reorderMarkers();
  }
  sendLocation(){
    this.handlers[MapSelector.Mode.DEFAULT].indicator.sendLocation();
  }
  getLocation(){
    this.handlers[MapSelector.Mode.DEFAULT].indicator.getLocation();
  }
}
