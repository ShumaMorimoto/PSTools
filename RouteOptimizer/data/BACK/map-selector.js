// map-selector.js
import MapInitializer from './map-initializer.js';
import ImageHandler from './image-handler.js';
import MarkerHandler from './marker-handler.js';
import UIManager from './ui-manager.js';
import { fetchAddressAsync } from './api-utils.js';

export default class MapSelector {
    constructor(options) {
        this.mapId = options.mapId;
        this.controls = options.controls;
        this.initialPoints = options.initialPoints || [];
        this.initialView = options.initialView || [35.6895, 139.6917, 12];

        this.map = null;
        this.imgGroup = null;
        this.isLocked = false;

        this.markerHandler = new MarkerHandler(this);
        this.imageHandler = new ImageHandler(this);
        this.uiManager = new UIManager(this);
        this.mapInitializer = new MapInitializer(this);
    }

    init() {
        this.mapInitializer.initMap();
        this.imageHandler.initImageHandlers();
        this.markerHandler.initMarkers();
        this.uiManager.initUIHandlers();

        window.addEventListener("beforeunload", () => {
            try { navigator.sendBeacon("/done"); } catch (e) { /* ignore */ }
        });

        this.uiManager.updateListUI();

        // 初期状態でロックモードに設定（トグルしてtrueにする）
        this.imageHandler.toggleLockMode();
    }

    // 共有メソッド（例: fetchAddressAsyncをインポートして使用）
    fetchAddressAsync(point, marker) {
        return fetchAddressAsync(point, marker, this.markerHandler);
    }
}