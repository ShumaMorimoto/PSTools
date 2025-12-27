// map-selector.js
import MapInitializer from "./map-initializer.js";
import MarkerHandler from "./marker-handler.js";
import ImageHandler from "./image-handler.js";
import TownHandler from "./town-handler.js";
import AreaHandler from "./area-handler.js";
import TrkptHandler from "./trkpt-handler.js";
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

  constructor(options) {
    this.mapId = options.mapId;
    this.controls = options.controls;
    this.initialView = options.initialView || [35.6895, 139.6917, 12];

    this.map = null;
    this.imgGroup = null;

    this.currentMode = MapSelector.Mode.DEFAULT;

    this.gpxService = options.gpxService;

    // Handlers
    this.markerHandler = new MarkerHandler(this, this.gpxService);
    this.imageHandler = new ImageHandler(this);
    this.townHandler = new TownHandler(this);
    this.areaHandler = new AreaHandler(this);
    this.trkptHandler = new TrkptHandler(this);
    this.splitHandler = new SplitHandler(this);
    this.gaHandler = new GAHandler(this, this.gpxService);

    this.uiManager = new UIManager(this);
    this.mapInitializer = new MapInitializer(this);
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  async init() {
    this.mapInitializer.initMap();

    this.imageHandler.init();
    this.markerHandler.initMarkers();
    this.uiManager.initUIHandlers();

    await this.townHandler.init();
    this.areaHandler.init();

    // 画像ボタン
    document
      .getElementById(this.controls.imageActionBtnId)
      .addEventListener("click", () => {
        this.currentMode = MapSelector.Mode.IMAGE_MODE;
        this.updateModeUI();
        this.imageHandler.onImageButtonClick();
      });

    // 町字追加ボタン
    document
      .getElementById(this.controls.townActionBtnId)
      .addEventListener("click", () => {
        this.currentMode = MapSelector.Mode.TOWN_MODE;
        this.updateModeUI();
        this.townHandler.onTownButtonClick();
      });

    // 領域追加ボタン
    document
      .getElementById(this.controls.areaActionBtnId)
      .addEventListener("click", () => {
        this.currentMode = MapSelector.Mode.AREA_MODE;
        this.updateModeUI();
        this.areaHandler.onAreaButtonClick();
      });

    // TRK処理ボタン
    document
      .getElementById(this.controls.processTrkptsBtnId)
      .addEventListener("click", () =>
        this.trkptHandler.onProcessButtonClick()
      );

    // 経路分割ボタン
    document
      .getElementById(this.controls.splitActionBtnId)
      .addEventListener("click", () => {
        this.currentMode = MapSelector.Mode.SPLIT_MODE;
        this.updateModeUI();
        this.splitHandler.onSplitButtonClick();
      });

    // ★ GA ボタン
    document
      .getElementById(this.controls.gaActionBtnId)
      .addEventListener("click", () => {
        this.currentMode = MapSelector.Mode.GA_MODE;
        this.updateModeUI();
        this.gaHandler.onGAButtonClick();
      });

    // 共通キャンセルボタン
    document
      .getElementById(this.controls.cancelActionBtnId)
      .addEventListener("click", () => {
        this._handleCancel();
      });

    window.addEventListener("beforeunload", () => {
      try {
        navigator.sendBeacon("/done");
      } catch (e) {}
    });

    this.uiManager.updateListUI();
    this.updateCancelButton();
  }

  // ---------------------------------------------------
  // キャンセルボタン押下
  // ---------------------------------------------------
  _handleCancel() {
    const handler = this._getHandlerForCurrentMode();
    if (handler?.onCancel) handler.onCancel();
  }

  updateCancelButton() {
    const btn = document.getElementById(this.controls.cancelActionBtnId);
    const handler = this._getHandlerForCurrentMode();

    btn.disabled = !(handler?.canCancel && handler.canCancel());
  }

  // ---------------------------------------------------
  // MapInitializer → click
  // ---------------------------------------------------
  handleMapClick(e) {
    const handler = this._getHandlerForCurrentMode();
    handler.handleMapClick?.(e);
  }

  handleMarkerClick(e, marker) {
    switch (this.currentMode) {
      case this.constructor.Mode.SPLIT_MODE:
        this.splitHandler.handleMarkerClick(marker);
        break;

      case this.constructor.Mode.GA_MODE:
        this.gaHandler.handleMarkerClick?.(marker);
        break;

      default:
        this.markerHandler.handleMarkerClick(e, marker);
        break;
    }
  }

  // ---------------------------------------------------
  // Handler 選択
  // ---------------------------------------------------
  _getHandlerForCurrentMode() {
    switch (this.currentMode) {
      case MapSelector.Mode.IMAGE_MODE:
        return this.imageHandler;

      case MapSelector.Mode.TOWN_MODE:
        return this.townHandler;

      case MapSelector.Mode.AREA_MODE:
        return this.areaHandler;

      case MapSelector.Mode.SPLIT_MODE:
        return this.splitHandler;

      case MapSelector.Mode.GA_MODE:
        return this.gaHandler;

      default:
        return this.markerHandler;
    }
  }

  // ---------------------------------------------------
  // UI 更新
  // ---------------------------------------------------
  updateModeUI() {
    const imageBtn = document.getElementById(this.controls.imageActionBtnId);
    const townBtn = document.getElementById(this.controls.townActionBtnId);
    const areaBtn = document.getElementById(this.controls.areaActionBtnId);
    const splitBtn = document.getElementById(this.controls.splitActionBtnId);
    const gaBtn = document.getElementById(this.controls.gaActionBtnId);

    imageBtn.classList.toggle(
      "active",
      this.currentMode === MapSelector.Mode.IMAGE_MODE
    );
    townBtn.classList.toggle(
      "active",
      this.currentMode === MapSelector.Mode.TOWN_MODE
    );
    areaBtn.classList.toggle(
      "active",
      this.currentMode === MapSelector.Mode.AREA_MODE
    );
    splitBtn.classList.toggle(
      "active",
      this.currentMode === MapSelector.Mode.SPLIT_MODE
    );
    gaBtn.classList.toggle(
      "active",
      this.currentMode === MapSelector.Mode.GA_MODE
    );

    this.updateCancelButton();
  }
}
