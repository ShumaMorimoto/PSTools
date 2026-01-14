import { initCoordinateControl } from "./components/leaflet-coordinate.js";
import { initPointListPanel } from "./components/leaflet-pointlist.js";
import { initButtonGroup } from "./components/leaflet-buttongroup.js";
import { initSearchControl } from "./components/leaflet-search.js";
import { markerEvents, MarkerEventTypes } from "./marker/marker-events.js";

// ボタンの定義データを確実にスコープ内に配置
const buttonGroups = {
  mainOptions: [
    {
      id: "list",
      status: "off",
      icon: '<i class="fas fa-list-ul"></i>',
      title: "拠点一覧",
    },
  ],
  redrawOptions: [
    {
      id: "polyline",
      status: "on",
      icon: '<i class="fas fa-pencil-alt"></i>',
      title: "Polyline",
    },
    {
      id: "cluster",
      status: "off",
      icon: '<i class="fas fa-braille"></i>',
      title: "クラスタ",
    },
    {
      id: "boundary",
      status: "off",
      icon: '<i class="fas fa-vector-square"></i>',
      title: "境界",
    },
  ],
  modeOptions: [
    {
      id: "addMarker",
      status: "idle",
      icon: '<i class="fas fa-plus-circle"></i>',
      title: "マーカー追加",
    },
    {
      id: "addImage",
      status: "idle",
      icon: '<i class="fas fa-image"></i>',
      title: "画像追加",
      fileInput: true,
    },
    {
      id: "addTown",
      status: "idle",
      icon: '<i class="fas fa-map-marker-alt"></i>',
      title: "町字追加",
    },
    {
      id: "addArea",
      status: "idle",
      icon: '<i class="fas fa-draw-polygon"></i>',
      title: "領域追加",
    },
    {
      id: "cancel",
      status: "off",
      icon: '<i class="fas fa-times"></i>',
      title: "キャンセル",
    },
  ],
  gpxOptions: [
    {
      id: "gpxLoad",
      status: "off",
      icon: '<i class="fas fa-file-import"></i>',
      title: "GPX追加",
      fileInput: true,
      accept: ".gpx",
    },
    {
      id: "gpxSave",
      status: "off",
      icon: '<i class="fas fa-file-export"></i>',
      title: "GPX保存",
    },
  ],
  historyOptions: [
    {
      id: "histLoad",
      status: "off",
      icon: '<i class="fas fa-history"></i>',
      title: "履歴読込",
      fileInput: true,
      accept: ".gpx",
    },
    {
      id: "histSave",
      status: "off",
      icon: '<i class="fas fa-hdd"></i>',
      title: "履歴保存",
    },
  ],
  updateOptions: [
    {
      id: "routeUpdate",
      status: "off",
      icon: '<i class="fas fa-route"></i>',
      title: "経路更新",
    },
    {
      id: "addrUpdate",
      status: "off",
      icon: '<i class="fas fa-map"></i>',
      title: "住所更新",
    },
    {
      id: "clear",
      status: "off",
      icon: '<i class="fas fa-trash"></i>',
      title: "クリア",
    },
  ],
};

export default class MapInitializer {
  constructor(selector) {
    this.selector = selector;
    this.groups = {}; 
  }

  /**
   * 1. 地図とコントロールの「器」を生成する
   */
  initMap() {
    initButtonGroup();
    initSearchControl();
    initPointListPanel();
    initCoordinateControl();

    this.selector.map = L.map(this.selector.mapId, {
      contextmenu: true,
      contextmenuWidth: 160,
      contextmenuItems: [],
    }).setView(
      [this.selector.initialView[0], this.selector.initialView[1]],
      this.selector.initialView[2]
    );

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors",
      maxZoom: 19,
    }).addTo(this.selector.map);

    this.selector.map.on("click", (e) => this.selector.handleMapClick(e));

    // ボタンの生成（ここではイベント登録はしない）
    Object.entries(buttonGroups).forEach(([groupName, buttons]) => {
      const group = L.control
        .buttonGroup({ position: "topleft", buttons })
        .addTo(this.selector.map);
      this.groups[groupName] = group;
      buttons.forEach((btn) => {
        if (btn.status) group.setStatus(btn.id, btn.status);
      });
    });

    this.selector.searchControl = L.control
      .searchWithHistory({ position: "topright" })
      .addTo(this.selector.map);

    this.selector.coordinatesControl = L.control
      .coordinateDistance({ position: "bottomleft" })
      .addTo(this.selector.map);

    this.selector.pointListControl = L.control
      .pointListPanel({
        getPoints: () => this.selector.gpxService.getTrkpts(),
        onSelect: (idx) => this.selector.zoomToMarkerByIndex(idx),
        onDelete: (idx) => {
          const marker = this.selector.handlers.default.getMarker(idx);
          this.selector.removeMarker(marker);
        },
      })
      .addTo(this.selector.map);

    // リストと距離表示の自動更新設定
    const updateUI = () => {
      const handler = this.selector.handlers.default;
      this.selector.coordinatesControl.updateDistance(
        handler.calcTotalDistance()
      );
      if (this.selector.pointListControl.isOpen()) {
        this.selector.pointListControl.updateList();
      }
    };

    markerEvents.addEventListener(MarkerEventTypes.LIST_CHANGED, updateUI);
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, updateUI);

    try {
      if (typeof L.distortableCollection === "function") {
        this.selector.imgGroup = L.distortableCollection().addTo(this.selector.map);
      }
    } catch (e) {
      console.warn("Image collection init failed", e);
    }
  }

  /**
   * 2. 各ハンドラ準備完了後にボタンの「クリックイベント」を紐付ける
   */
  setupEventHandlers() {
    const modes = this.selector.constructor.Mode;

    // --- Main Options ---
    this.groups.mainOptions.setButtonHandler("list", {
      onClick: () => {
        const isOpen = this.selector.pointListControl.toggle();
        this.groups.mainOptions.setStatus("list", isOpen ? "active" : "default");
      },
    });

    // --- Redraw Options ---
    this.groups.redrawOptions.setButtonHandler("polyline", {
      onClick: () => {
        const next = this.groups.redrawOptions.getStatus("polyline") === "on" ? "off" : "on";
        this.groups.redrawOptions.setStatus("polyline", next);
        this.selector.handleTogglePolyline(next);
      },
    });

    this.groups.redrawOptions.setButtonHandler("cluster", {
      onClick: () => {
        const next = this.groups.redrawOptions.getStatus("cluster") === "on" ? "off" : "on";
        this.groups.redrawOptions.setStatus("cluster", next);
        this.selector.handleToggleCluster(next);
      },
    });

    this.groups.redrawOptions.setButtonHandler("boundary", {
      onClick: () => {
        const next = this.groups.redrawOptions.getStatus("boundary") === "on" ? "off" : "on";
        this.groups.redrawOptions.setStatus("boundary", next);
        this.selector.handleToggleBoundary(next);
      },
    });

    // --- Mode Options ---
    this.groups.modeOptions.setButtonHandler("addMarker", {
      onClick: () => {
        this.selector.setMode(modes.DEFAULT);
        this.selector.handlers.default.onActionButtonClick();
      },
    });

    this.groups.modeOptions.setButtonHandler("addImage", {
      cndFileInput: (map, btnId) => this.groups.modeOptions.getStatus(btnId) === "idle",
      onClick: () => {
        this.selector.setMode(modes.IMAGE_MODE);
        this.selector.handlers.imageMode.onActionButtonClick?.();
      },
      onFile: (map, file) => {
        this.selector.setMode(modes.IMAGE_MODE);
        this.selector.handlers.imageMode.onFileInputClick?.(file);
      },
    });

    this.groups.modeOptions.setButtonHandler("addTown", {
      onClick: () => {
        this.selector.setMode(modes.TOWN_MODE);
        this.selector.handlers.townMode.onActionButtonClick?.();
      },
    });

    this.groups.modeOptions.setButtonHandler("addArea", {
      onClick: () => {
        this.selector.setMode(modes.AREA_MODE);
        this.selector.handlers.areaMode.onActionButtonClick?.();
      },
    });

    this.groups.modeOptions.setButtonHandler("cancel", {
      onClick: () => this.selector.handleCancel(),
    });

    // --- GPX Options ---
    this.groups.gpxOptions.setButtonHandler("gpxLoad", {
      cndFileInput: true,
      onFile: (map, file) => this.selector.handleGpxLoad(file),
    });

    this.groups.gpxOptions.setButtonHandler("gpxSave", {
      onClick: () => this.selector.handleGpxSave(),
    });

    // --- History Options ---
    this.groups.historyOptions.setButtonHandler("histLoad", {
      cndFileInput: true,
      onFile: (map, file) => this.selector.uiManager.handleHistoryLoad(file),
    });

    this.groups.historyOptions.setButtonHandler("histSave", {
      onClick: () => this.selector.uiManager.handleHistorySave(),
    });

    // --- Update Options ---
    this.groups.updateOptions.setButtonHandler("routeUpdate", {
      onClick: () => this.selector.reorderMarkers(),
    });

    this.groups.updateOptions.setButtonHandler("addrUpdate", {
      onClick: () => this.selector.reFetchAllAddresses(),
    });

    this.groups.updateOptions.setButtonHandler("clear", {
      onClick: () => this.selector.clearMarkers(),
    });
  }
}