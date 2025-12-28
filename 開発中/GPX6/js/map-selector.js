// map-selector.js
import MapInitializer from "./map-initializer.js";
import MarkerHandler from "./marker-handler.js";
import ImageHandler from "./image-handler.js";
import TownHandler from "./town-handler.js";
import AreaHandler from "./area-handler.js";
import SplitHandler from "./split-handler.js";
import GAHandler from "./ga-handler.js";
import UIManager from "./ui-manager.js";

export default class MapSelector {
  static Mode = {
    DEFAULT: "default",
    IMAGE_MODE: "imageMode",
    TOWN_MODE: "townMode",
    AREA_MODE: "areaMode",
    SPLIT_MODE: "splitMode",
    GA_MODE: "gaMode",
  };

  // Mode → UIボタンIDキー / Handlerクラス の対応表
  static ModeConfig = {
    [MapSelector.Mode.IMAGE_MODE]: {
      controlKey: "imageActionBtnId",
      handlerClass: ImageHandler,
    },
    [MapSelector.Mode.TOWN_MODE]: {
      controlKey: "townActionBtnId",
      handlerClass: TownHandler,
    },
    [MapSelector.Mode.AREA_MODE]: {
      controlKey: "areaActionBtnId",
      handlerClass: AreaHandler,
    },
    [MapSelector.Mode.SPLIT_MODE]: {
      controlKey: "splitActionBtnId",
      handlerClass: SplitHandler,
    },
    [MapSelector.Mode.GA_MODE]: {
      controlKey: "gaActionBtnId",
      handlerClass: GAHandler,
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

    this.gpxService = options.gpxService;

    // Handler インスタンスを Map で管理
    this.handlers = {
      [MapSelector.Mode.DEFAULT]: new MarkerHandler(this),
    };

    // ModeConfig から Handler を生成
    Object.entries(MapSelector.ModeConfig).forEach(([mode, cfg]) => {
      this.handlers[mode] = new cfg.handlerClass(this);
    });

    this.uiManager = new UIManager(this);
    this.mapInitializer = new MapInitializer(this);
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  async init() {
    this.mapInitializer.initMap();
    this.uiManager.initUIHandlers();

    // 必要な Handler の init
    Object.values(this.handlers).forEach((h) => h.init?.());

    // MODE ボタンをループでバインド
    Object.entries(MapSelector.ModeConfig).forEach(([mode, cfg]) => {
      const btnId = this.controls[cfg.controlKey];
      const handler = this.handlers[mode];
      this._bindModeButton(btnId, mode, handler);
    });

    // キャンセルボタン
    document
      .getElementById(this.controls.cancelActionBtnId)
      .addEventListener("click", () => this.handleCancel());

    // beforeunload
    window.addEventListener("beforeunload", () => {
      try {
        navigator.sendBeacon("/done");
      } catch (e) {}
    });

    // 初期 Handler
    this.currentHandler = this.handlers[MapSelector.Mode.DEFAULT];

    // 初期 UI
    this.uiManager.updateModeButtons(this.currentMode);
  }

  // ---------------------------------------------------
  // MODE ボタン共通バインド
  // ---------------------------------------------------
  _bindModeButton(btnId, mode, handler) {
    document.getElementById(btnId).addEventListener("click", () => {
      this.setMode(mode);
      handler.onActionButtonClick?.();
    });
  }

  // ---------------------------------------------------
  // MODE 変更
  // ---------------------------------------------------
  setMode(mode) {
    this.currentMode = mode;
    this.currentHandler =
      this.handlers[mode] || this.handlers[MapSelector.Mode.DEFAULT];

    this.uiManager.updateModeButtons(mode);
  }

  // ---------------------------------------------------
  // Handler → Selector → UIManager
  // ---------------------------------------------------
  onHandlerStateChanged(info) {
    this.uiManager.updateStateUI(info);
    this.updateList();
  }

  updateList() {
    this.uiManager.updateListUI();
  }

  // ---------------------------------------------------
  // キャンセル
  // ---------------------------------------------------
  handleCancel() {
    this.currentHandler.handleCancel?.();
  }

  // ---------------------------------------------------
  // Map click
  // ---------------------------------------------------
  handleMapClick(e) {
    this.currentHandler.handleMapClick?.(e);
  }

  // ---------------------------------------------------
  // Marker click
  // ---------------------------------------------------
  handleMarkerClick(e, marker) {
    this.currentHandler.handleMarkerClick?.(e, marker);
  }

  // ===================================================
  // ここから Selector の再定義（Facade API）
  // ===================================================

  // 1. addPoint
  addPoint(tp) {
    this.handlers[MapSelector.Mode.DEFAULT].addPoint(tp);
  }

  // 2. removeMarker
  removeMarker(marker, removeTrkpt = true) {
    this.handlers[MapSelector.Mode.DEFAULT].removeMarker(marker, removeTrkpt);
  }

  // 3. clearMarkers
  clearMarkers() {
    this.handlers[MapSelector.Mode.DEFAULT].clearMarkers();
  }

  // 4. zoomToMarkerByIndex（UIManager 用）
  zoomToMarkerByIndex(idx) {
    this.handlers[MapSelector.Mode.DEFAULT].zoomToMarkerByIndex(idx);
  }

  // 5. reFetchAllAddresses
  reFetchAllAddresses() {
    this.handlers[MapSelector.Mode.DEFAULT].reFetchAllAddresses();
  }

  startReorderSession() {
    return this.handlers[MapSelector.Mode.DEFAULT].beginReorderSession();
  }

  applyReorder(indices) {
    this.handlers[MapSelector.Mode.DEFAULT].applyReorder(indices);
  }

  getLatestReorderIndices() {
    return this.handlers[MapSelector.Mode.DEFAULT].getLatestReorderIndices();
  }

  confirmReorder(indices) {
    this.handlers[MapSelector.Mode.DEFAULT].confirmReorder(indices);
  }

  cancelReorder() {
    this.handlers[MapSelector.Mode.DEFAULT].cancelReorder();
  }
}
