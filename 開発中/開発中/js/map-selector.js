// map-selector.js
import MapInitializer from "./map-initializer.js";
import ImageHandler from "./image-handler.js";
import MarkerHandler from "./marker-handler.js";
import UIManager from "./ui-manager.js";
import { fetchAddressAsync } from "./api-utils.js";
import GPXService from "./gpx-service.js";

export default class MapSelector {
  constructor(options) {
    this.mapId = options.mapId;
    this.controls = options.controls;
    this.initialPoints = options.initialPoints || [];
    this.initialView = options.initialView || [35.6895, 139.6917, 12];

    this.map = null;
    this.imgGroup = null;
    this.isLocked = false;

    // ✅ GPXService
    this.gpxService = new GPXService();

    // ✅ MarkerHandler に selector と gpxService を渡す
    this.markerHandler = new MarkerHandler(this, this.gpxService);

    this.imageHandler = new ImageHandler(this);
    this.uiManager = new UIManager(this);
    this.mapInitializer = new MapInitializer(this);
  }

  init() {
    // ✅ 地図初期化
    this.mapInitializer.initMap();

    // ✅ 各ハンドラ初期化
    this.imageHandler.initImageHandlers();
    this.markerHandler.initMarkers();
    this.uiManager.initUIHandlers();

    // ✅ ページ離脱通知
    window.addEventListener("beforeunload", () => {
      try {
        navigator.sendBeacon("/done");
      } catch (e) {}
    });

    // ✅ UI 初期更新
    this.uiManager.updateListUI();

    // ✅ 初期状態でロックモード（あなたの仕様）
    this.imageHandler.toggleLockMode();
  }

  // ✅ 住所取得（api-utils.js）
  fetchAddressAsync(point, marker) {
    return fetchAddressAsync(point, marker, this.markerHandler);
  }
}
