// map-initializer.js

const buttonGroups = {
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
      id: "addImage",
      status: "off",
      icon: '<i class="fas fa-image"></i>',
      title: "画像追加",
      fileInput: true,
      accept: "image/*",
    },

    {
      id: "addTown",
      status: "off",
      icon: '<i class="fas fa-map-marker-alt"></i>',
      title: "町字追加",
    },
    {
      id: "addArea",
      status: "off",
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
      icon: '<i class="fas fa-map-marker-alt"></i>',
      title: "GPX追加",
      fileInput: true,
      accept: ".gpx",
    },
    {
      id: "gpxSave",
      status: "off",
      icon: '<i class="fas fa-save"></i>',
      title: "GPX保存",
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
  }

  initMap() {
    // ----------------------------------------
    // 地図生成
    // ----------------------------------------
    this.selector.map = L.map(this.selector.mapId, {
      contextmenu: true,
      contextmenuWidth: 160,
      contextmenuItems: [],
    }).setView(
      [this.selector.initialView[0], this.selector.initialView[1]],
      this.selector.initialView[2]
    );

    // ----------------------------------------
    // タイル
    // ----------------------------------------
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors",
      maxZoom: 19,
    }).addTo(this.selector.map);

    // ----------------------------------------
    // 地図クリック → Selector に通知
    // ----------------------------------------
    this.selector.map.on("click", (e) => {
      this.selector.handleMapClick(e);
    });

    const groups = {};

    Object.entries(buttonGroups).forEach(([groupName, buttons]) => {
      const group = L.control
        .buttonGroup({
          position: "topleft",
          buttons,
        })
        .addTo(this.selector.map);
      groups[groupName] = group;

      // 初期 status を設定
      buttons.forEach((btn) => {
        if (btn.status) {
          group.setStatus(btn.id, btn.status);
        }
      });
    });

    // -------------------------
    // ---------------
    // ★ SearchService を Leaflet UI に接続（正しい場所）
    // ----------------------------------------
    if (this.selector.searchService) {
      const searchControl = new window.GeoSearch.GeoSearchControl({
        provider: {
          search: (query) => this.selector.searchService.search(query),
        },
        style: "bar",
        autoComplete: true,
        autoCompleteDelay: 200,
        showMarker: false,
        retainZoomLevel: true,
        animateZoom: true,
        autoClose: false,
        searchLabel: "場所を検索...",
      });

      this.selector.map.addControl(searchControl);
      this.selector.map.on("geosearch/showlocation", (e) => {
        const trkpt = e.location.raw;

        // 仮マーカー生成（UI層の責務）
        this.selector.handleShowLocation(trkpt);

        // ★ 履歴更新（Service の責務）
        this.selector.searchService.showLocation(trkpt);
      });
    }

    // ----------------------------------------
    // 座標表示
    // ----------------------------------------
    const CoordinateControl = L.Control.extend({
      options: { position: "bottomleft" },

      onAdd: function (map) {
        // コンテナ
        this._container = L.DomUtil.create(
          "div",
          "leaflet-control-mouseposition"
        );
        this._coordDiv = L.DomUtil.create("div", "", this._container);
        this._coordDiv.innerHTML = "— , —";
        this._distDiv = L.DomUtil.create("div", "", this._container);
        this._distDiv.innerHTML = "0 m";

        // マウス移動で座標更新
        map.on("mousemove", (e) => {
          this._coordDiv.innerHTML = `${e.latlng.lat.toFixed(
            5
          )}, ${e.latlng.lng.toFixed(5)}`;
        });
        return this._container;
      },
      // ★ 外部から距離をセットするメソッド
      updateDistance: function (meters) {
        if (!this._distDiv) return;
        this._distDiv.innerHTML = `${(meters / 1000).toFixed(2)} km`;
      },
    });
    // コントロールを地図に追加
    this.selector.coordinatesControl = new CoordinateControl().addTo(
      this.selector.map
    );

    // ----------------------------------------
    // distortableCollection
    // ----------------------------------------
    try {
      if (typeof L.distortableCollection === "function") {
        this.selector.imgGroup = L.distortableCollection().addTo(
          this.selector.map
        );
      } else {
        console.warn("L.distortableCollection is not available.");
        this.selector.imgGroup = {
          eachLayer: () => {},
          addLayer: () => {},
          removeLayer: () => {},
        };
      }
    } catch (e) {
      console.warn("distortableCollection init failed", e);
      this.selector.imgGroup = {
        eachLayer: () => {},
        addLayer: () => {},
        removeLayer: () => {},
      };
    }

    //
    //  リスト表示
    //
    L.Control.pointList = L.Control.extend({
      options: {
        position: "topright",
        getPoints: null, // () => [{name, lat, lon}, ...]
        onSelect: null, // (idx) => void
      },
      onAdd: function (map) {
        const container = L.DomUtil.create("div", "leaflet-control-pointlist");
        this.select = L.DomUtil.create("select", "", container);

        L.DomEvent.disableClickPropagation(container);
        L.DomEvent.disableScrollPropagation(container);

        this.select.addEventListener("change", () => {
          const val = this.select.value;
          if (val === "" || isNaN(val)) return;
          const idx = parseInt(val, 10);
          if (typeof this.options.onSelect === "function") {
            this.options.onSelect(idx);
          }
        });
        return container;
      },
      updateList: function () {
        if (!this.select) return;
        this.select.innerHTML = "";

        if (typeof this.options.getPoints !== "function") return;

        const pts = this.options.getPoints();
        if (!pts || !Array.isArray(pts)) return;

        pts.forEach((p, i) => {
          const opt = document.createElement("option");
          opt.value = i;
          opt.textContent = `${i + 1}. ${
            p.name || p.desc || `${p.lat}, ${p.lon}`
          }`;
          this.select.appendChild(opt);
        });
      },
    });
    L.control.pointList = function (opts) {
      return new L.Control.pointList(opts);
    };
    this.selector.pointListControl = L.control
      .pointList({
        getPoints: () => this.selector.gpxService.getTrkpts(),
        onSelect: (idx) => this.selector.zoomToMarkerByIndex(idx),
      })
      .addTo(this.selector.map);

    // ----------------------------------------
    // UI → Handler 通知
    // ----------------------------------------

    // redrawOptions のボタン → ハンドラ対応表
    const redrawHandlers = {
      polyline: () => {
        const current = groups.redrawOptions.getStatus("polyline");
        const next = current === "on" ? "off" : "on";
        groups.redrawOptions.setStatus("polyline", next);
        this.selector.handleTogglePolyline(next);
      },

      cluster: () => {
        const current = groups.redrawOptions.getStatus("cluster");
        const next = current === "on" ? "off" : "on";
        groups.redrawOptions.setStatus("cluster", next);
        this.selector.handleToggleCluster(next);
      },

      boundary: () => {
        const current = groups.redrawOptions.getStatus("boundary");
        const next = current === "on" ? "off" : "on";
        groups.redrawOptions.setStatus("boundary", next);
        this.selector.handleToggleBoundary(next);
      },
    };
    // ループで登録（美しい）
    Object.entries(redrawHandlers).forEach(([btnId, handler]) => {
      groups.redrawOptions.onClick(btnId, handler);
    });

    // GPX追加（ファイル入力）
    groups.gpxOptions.onFile("gpxLoad", (map, file) => {
      this.selector.handleGpxLoad(file);
    });
    // GPX保存
    groups.gpxOptions.onClick("gpxSave", () => {
      this.selector.handleGpxSave();
    });
    // 経路更新（rerouteButton）
    groups.updateOptions.onClick("routeUpdate", () => {
      this.selector.reorderMarkers();
    });
    // 住所更新（addressUpButton）
    groups.updateOptions.onClick("addrUpdate", () => {
      this.selector.reFetchAllAddresses();
    });
    // クリア（clearButton）
    groups.updateOptions.onClick("clear", () => {
      this.selector.clearMarkers();
    });

    // IMAGE_MODE
    groups.modeOptions.onClick("addImage", () => {
      this.setMode(MapSelector.Mode.IMAGE_MODE);
      new ImageHandler(this.selector).onActionButtonClick?.();
    });

    // TOWN_MODE
    groups.modeOptions.onClick("addTown", () => {
      this.setMode(MapSelector.Mode.TOWN_MODE);
      new TownHandler(this.selector).onActionButtonClick?.();
    });

    // AREA_MODE
    groups.modeOptions.onClick("addArea", () => {
      this.setMode(MapSelector.Mode.AREA_MODE);
      new AreaHandler(this.selector).onActionButtonClick?.();
    });

    // CANCEL_MODE（必要なら）
    groups.modeOptions.onClick("cancel", () => {
      this.setMode(MapSelector.Mode.NONE);
    });
  }
}
