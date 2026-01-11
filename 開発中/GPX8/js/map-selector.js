// map-selector.js
import GPXService from "./gpx-service.js";
import MapInitializer from "./map-initializer.js";
import MarkerHandler from "./marker-handler.js";
import ImageHandler from "./image-handler.js";
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

  // Mode → UIボタンIDキー / Handlerクラス の対応表
  static ModeConfig = {
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
  async init(initData) {
    this.mapInitializer.initMap();
    this.uiManager.initUIHandlers();

    // 必要な Handler の init
    Object.values(this.handlers).forEach((h) => h.init?.());

    const modeBtns = this.mapInitializer.groups.modeOptions;
    
    // モードボタンのハンドラ登録
    modeBtns.setButtonHandler("addImage", {
      cndFileInput: (map, btnId) => {
        const currentStatus = modeBtns.getStatus(btnId);
        return currentStatus === "idle";
      },
      onClick: (map, e) => {
        this.setMode(MapSelector.Mode.IMAGE_MODE);
        this.handlers[MapSelector.Mode.IMAGE_MODE].onActionButtonClick?.();
      },
      onFile: (map, file, e) => {
        this.setMode(MapSelector.Mode.IMAGE_MODE);
        this.handlers[MapSelector.Mode.IMAGE_MODE].onFileInputClick?.(file);
      },
    });

    modeBtns.setButtonHandler("addTown", {
      onClick: (map, e) => {
        this.setMode(MapSelector.Mode.TOWN_MODE);
        this.handlers[MapSelector.Mode.TOWN_MODE].onActionButtonClick?.();
      },
    });

    modeBtns.setButtonHandler("addArea", {
      onClick: (map, e) => {
        this.setMode(MapSelector.Mode.AREA_MODE);
        this.handlers[MapSelector.Mode.AREA_MODE].onActionButtonClick?.();
      },
    });

    modeBtns.setButtonHandler("cancel", {
      onClick: (map, e) => this.handleCancel(),
    });

    // 終了時処理
    window.addEventListener("beforeunload", () => {
      try { navigator.sendBeacon("/done"); } catch (e) {}
    });

    // 初期状態の設定
    this.currentHandler = this.handlers[MapSelector.Mode.DEFAULT];
    this.uiManager.updateModeButtons(this.currentMode);

    // 検索結果選択時のプレビュー処理をバインド
    this.searchControl.bindOnLocationSelected(
      this.handlers[MapSelector.Mode.DEFAULT].preview.onSelected
    );

    // Toast通知の初期化
    initToast(document.getElementById(this.controls.toastId));

    // 初期データがあればモデルにロード
    if (initData) {
      this.handlers[MapSelector.Mode.DEFAULT].setModel(initData);
    }
  }

  // ---------------------------------------------------
  // 表示切替 (Initializer 側のボタンから呼ばれる)
  // ---------------------------------------------------
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
  // GPX操作
  // ---------------------------------------------------
  handleGpxLoad(file) {
    this.uiManager.handleGpxLoad(file);
  }
  handleGpxSave() {
    this.uiManager.handleGpxSave();
  }

  // ---------------------------------------------------
  // モード制御
  // ---------------------------------------------------
  setMode(mode) {
    this.currentMode = mode;
    this.currentHandler = this.handlers[mode] || this.handlers[MapSelector.Mode.DEFAULT];
    this.uiManager.updateModeButtons(mode);
  }

  /**
   * Handler からの状態変更通知
   */
  onHandlerStateChanged({ state, canCancel }) {
    const mode = this.currentMode;
    // デフォルトモード以外（画像、町字、領域）の時は、ボタングステータス（色等）を更新
    if (mode !== MapSelector.Mode.DEFAULT) {
      const buttonId = MapSelector.ModeConfig[mode].buttonId;
      this.uiManager.updateStateUI({
        buttonId,
        state,
        canCancel,
      });
    }
  }

  // ---------------------------------------------------
  // 地図・マーカーイベントの中継 (CurrentHandlerへ)
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

  // ===================================================
  // Facade API (外部・UIManager・外部スクリプト用)
  // ===================================================

  addPoint(p) {
    this.handlers[MapSelector.Mode.DEFAULT].addPoint(p);
  }

  addPoints(pts) {
    this.handlers[MapSelector.Mode.DEFAULT].addPoints(pts);
  }

  removeMarker(marker, removeTrkpt = true) {
    this.handlers[MapSelector.Mode.DEFAULT].removeMarker(marker, removeTrkpt);
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
}