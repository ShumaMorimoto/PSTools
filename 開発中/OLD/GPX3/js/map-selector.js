// map-selector.js
import MapInitializer from "./map-initializer.js";
import MarkerHandler from "./marker-handler.js";
import ImageHandler from "./image-handler.js";
import TownHandler from "./town-handler.js";
import AreaHandler from "./area-handler.js";
import TrkptHandler from "./trkpt-handler.js";
import SplitHandler from "./split-handler.js"; // ★ 追加
import UIManager from "./ui-manager.js";

export default class MapSelector {
  static Mode = {
    DEFAULT: "default",
    IMAGE_MODE: "imageMode",
    TOWN_MODE: "townMode",
    AREA_MODE: "areaMode",
    SPLIT_MODE: "splitMode", // ★ 追加
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
    this.splitHandler = new SplitHandler(this); // ★ 追加

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
        this.imageHandler.onImageButtonClick();
      });

    // 町字追加ボタン
    document
      .getElementById(this.controls.townActionBtnId)
      .addEventListener("click", () => {
        this.townHandler.onTownButtonClick();
      });

    // 領域追加ボタン
    document
      .getElementById(this.controls.areaActionBtnId)
      .addEventListener("click", () => {
        this.areaHandler.onAreaButtonClick();
      });

    // TRK処理ボタン
    document
      .getElementById(this.controls.processTrkptsBtnId)
      .addEventListener("click", () =>
        this.trkptHandler.onProcessButtonClick()
      );

    // ★ 経路分割ボタン
    document
      .getElementById(this.controls.splitActionBtnId)
      .addEventListener("click", () => {
        this.splitHandler.onSplitButtonClick();
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
    if (handler?.onCancel) {
      handler.onCancel();
    }
  }

  updateCancelButton() {
    const btn = document.getElementById(this.controls.cancelActionBtnId);
    const handler = this._getHandlerForCurrentMode();

    if (handler?.canCancel && handler.canCancel()) {
      btn.disabled = false;
    } else {
      btn.disabled = true;
    }
  }

  // ---------------------------------------------------
  // MapInitializer からのクリック通知
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

      case this.constructor.Mode.DEFAULT:
      default:
        this.markerHandler.handleMarkerClick(e, marker);
        break;
    }
  }
  
  // ---------------------------------------------------
  // モードに応じて Handler を返す
  // ---------------------------------------------------
  _getHandlerForCurrentMode() {
    switch (this.currentMode) {
      case MapSelector.Mode.IMAGE_MODE:
        return this.imageHandler;

      case MapSelector.Mode.TOWN_MODE:
        return this.townHandler;

      case MapSelector.Mode.AREA_MODE:
        return this.areaHandler;

      case MapSelector.Mode.SPLIT_MODE: // ★ 追加
        return this.splitHandler;

      case MapSelector.Mode.DEFAULT:
      default:
        return this.markerHandler;
    }
  }

  // ---------------------------------------------------
  // UI 更新（アクティブボタンの見た目）
  // ---------------------------------------------------
  updateModeUI() {
    const imageBtn = document.getElementById(this.controls.imageActionBtnId);
    const townBtn = document.getElementById(this.controls.townActionBtnId);
    const areaBtn = document.getElementById(this.controls.areaActionBtnId);
    const splitBtn = document.getElementById(this.controls.splitActionBtnId); // ★ 追加

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
    ); // ★ 追加

    this.updateCancelButton();
  }
}
