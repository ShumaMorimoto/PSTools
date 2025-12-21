// map-selector.js
import MapInitializer from "./map-initializer.js";
import MarkerHandler from "./marker-handler.js";
import ImageHandler from "./image-handler.js";
import TownHandler from "./town-handler.js";
import AreaHandler from "./area-handler.js";
import UIManager from "./ui-manager.js";
import { fetchAddressAsync } from "./api-utils.js";
import GPXService from "./gpx-service.js";

export default class MapSelector {
  static Mode = {
    DEFAULT: "default",
    IMAGE_MODE: "imageMode",
    TOWN_MODE: "townMode",
    AREA_MODE: "areaMode",
  };

  constructor(options) {
    this.mapId = options.mapId;
    this.controls = options.controls;
    this.initialView = options.initialView || [35.6895, 139.6917, 12];

    this.map = null;
    this.imgGroup = null;

    this.currentMode = MapSelector.Mode.DEFAULT;

    this.gpxService = options.gpxService;

    // ✅ Handler 群
    this.markerHandler = new MarkerHandler(this, this.gpxService);
    this.imageHandler = new ImageHandler(this);
    this.townHandler = new TownHandler(this);
    this.areaHandler = new AreaHandler(this);

    this.uiManager = new UIManager(this);
    this.mapInitializer = new MapInitializer(this);
  }

  // ---------------------------------------------------
  // ✅ 初期化
  // ---------------------------------------------------
  async init() {
    this.mapInitializer.initMap();

    this.imageHandler.init();
    this.markerHandler.initMarkers();
    this.uiManager.initUIHandlers();

    await this.townHandler.init();
    this.areaHandler.init();

    // ✅ 画像ボタン
    document
      .getElementById(this.controls.imageActionBtnId)
      .addEventListener("click", () => {
        this.imageHandler.onImageButtonClick();
      });

    // ✅ 町字追加ボタン
    document
      .getElementById(this.controls.townActionBtnId)
      .addEventListener("click", () => {
        this.townHandler.onTownButtonClick();
      });

    // ✅ 領域追加ボタン
    document
      .getElementById(this.controls.areaActionBtnId)
      .addEventListener("click", () => {
        this.areaHandler.onAreaButtonClick();
      });

    // ✅ 共通キャンセルボタン
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
  // ✅ キャンセルボタン押下 → 各ハンドラに委譲
  // ---------------------------------------------------
  _handleCancel() {
    const handler = this._getHandlerForCurrentMode();
    if (handler?.onCancel) {
      handler.onCancel();
    }
    this.updateCancelButton();
  }

  // ---------------------------------------------------
  // ✅ キャンセルボタンの有効/無効を更新
  // ---------------------------------------------------
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
  // ✅ Initializer からのクリック通知
  // ---------------------------------------------------
  handleMapClick(e) {
    const handler = this._getHandlerForCurrentMode();
    handler.handleMapClick(e);
    this.updateCancelButton();
  }

  // ---------------------------------------------------
  // ✅ モードに応じて Handler を返す
  // ---------------------------------------------------
  _getHandlerForCurrentMode() {
    switch (this.currentMode) {
      case MapSelector.Mode.IMAGE_MODE:
        return this.imageHandler;

      case MapSelector.Mode.TOWN_MODE:
        return this.townHandler;

      case MapSelector.Mode.AREA_MODE:
        return this.areaHandler;

      case MapSelector.Mode.DEFAULT:
      default:
        return this.markerHandler;
    }
  }

  // ---------------------------------------------------
  // ✅ UI 更新（アクティブボタンの見た目だけ）
  // ---------------------------------------------------
  updateModeUI() {
    const imageBtn = document.getElementById(this.controls.imageActionBtnId);
    const townBtn = document.getElementById(this.controls.townActionBtnId);
    const areaBtn = document.getElementById(this.controls.areaActionBtnId);

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

    this.updateCancelButton();
  }

  fetchAddressAsync(point, marker) {
    return fetchAddressAsync(point, marker, this.markerHandler);
  }
}