// map-selector.js
import MapInitializer from "./map-initializer.js";
import MarkerHandler from "./marker-handler.js";
import ImageHandler from "./image-handler.js";
import TownHandler from "./town-handler.js";
import AreaHandler from "./area-handler.js";
//import GAHandler from "./ga-handler.js";
import UIManager from "./ui-manager.js";
import SearchService from "./search-service.js";
import { initToast } from "./api-utils.js";

export default class MapSelector {
  static Mode = {
    DEFAULT: "default",
    IMAGE_MODE: "imageMode",
    TOWN_MODE: "townMode",
    AREA_MODE: "areaMode",
    //    GA_MODE: "gaMode",
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
    //    [MapSelector.Mode.GA_MODE]: {
    //      controlKey: "gaActionBtnId",
    //      handlerClass: GAHandler,
    //    },
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

    this.searchService = new SearchService(this);
    this.uiManager = new UIManager(this);
    this.mapInitializer = new MapInitializer(this);
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  async init(initData) {
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

    this._bindUIEvents();

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

    // toast

    initToast(document.getElementById(this.controls.toastId))

    // 初期データがあればモデルにロード
    if (initData) {
      this.handlers[MapSelector.Mode.DEFAULT].setModel(initData);
    }
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

  _bindUIEvents() {
    // pointList
    document
      .getElementById(this.controls.pointListId)
      .addEventListener("change", () => this.uiManager.handlePointListChange());

    // 経路最適化
    document
      .getElementById(this.controls.updateRouteBtnId)
      .addEventListener("click", () => this.reorderMarkers());

    // 住所再取得
    document
      .getElementById(this.controls.reFetchBtnId)
      .addEventListener("click", () => this.reFetchAllAddresses());

    // マーカー全削除
    document
      .getElementById(this.controls.clearMarkersBtnId)
      .addEventListener("click", () => this.clearMarkers());

    document
      .getElementById(this.controls.gpxInputId)
      .addEventListener("change", (e) => this.uiManager.handleGpxLoad(e));

    document
      .getElementById(this.controls.gpxSaveId)
      .addEventListener("click", () => this.uiManager.handleGpxSave());
  }

  handleTogglePolyline() {
    this.handlers[MapSelector.Mode.DEFAULT].polyline.toggle();
  }

  handleToggleCluster() {
    this.handlers[MapSelector.Mode.DEFAULT].cluster.toggle();
  }

  handleToggleBoundary() {
    this.handlers[MapSelector.Mode.DEFAULT].boundary.toggle();
  }

  // ---------------------------------------------------
  // Geocoder → MarkerHandler（仮マーカー表示）
  // ---------------------------------------------------
  handleShowLocation(trkpt) {
    this.handlers[MapSelector.Mode.DEFAULT].addPreviewMarker(trkpt);
  }

  handleToggleBoundary() {
    this.handlers[MapSelector.Mode.DEFAULT].boundary.toggle();
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
  addPoint(p) {
    this.handlers[MapSelector.Mode.DEFAULT].addPoint(p);
  }
  addPoints(pts) {
    this.handlers[MapSelector.Mode.DEFAULT].addPoints(pts);
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
  updateAddress(m) {
    this.handlers[MapSelector.Mode.DEFAULT].address.updateAddress(m);
  }

  reFetchAllAddresses() {
    this.handlers[MapSelector.Mode.DEFAULT].address.reFetchAllAddresses();
  }



  reorderMarkers() {
    this.handlers[MapSelector.Mode.DEFAULT].reorderMarkers();
  }

  drawBorder(m) {
    this.handlers[MapSelector.Mode.DEFAULT].border.drawBorder(m);
  }
}
