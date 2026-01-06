// map-initializer.js

const buttonGroups = {
  mainOptions: [
    {
      id: "list", // これを追加
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
    this.groups = groups;

    // コントロールのインスタンス化と追加（元のコードの置き換え）
    // 初期化時

    this.selector.searchControl = L.control
      .searchWithHistory({ position: "topright" })
      .addTo(this.selector.map);

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

    // 1. パネルの作成
    this.selector.pointListControl = L.control
      .pointListPanel({
        getPoints: () => this.selector.gpxService.getTrkpts(),
        onSelect: (idx) => this.selector.zoomToMarkerByIndex(idx),
      })
      .addTo(this.selector.map);

    // 2. 左側のボタングループのハンドラ設定
    groups.mainOptions.setButtonHandler("list", {
      onClick: () => {
        console.log("Control Instance:", this.selector.pointListControl);
        console.log("Toggle Method:", this.selector.pointListControl.toggle);
        // パネルの開閉
        const isOpen = this.selector.pointListControl.toggle();
        // ボタンの見た目を更新
        groups.mainOptions.setStatus("list", isOpen ? "active" : "default");

        if (isOpen) {
          this.selector.pointListControl.updateList();
        }
      },
    });
    

    // ----------------------------------------
    // UI → Handler 通知
    // ----------------------------------------

    // --- 表示切替関連グループ (Redraw Options) ---
    // ポリライン表示切替
    groups.redrawOptions.setButtonHandler("polyline", {
      onClick: () => {
        const current = groups.redrawOptions.getStatus("polyline");
        const next = current === "on" ? "off" : "on";
        groups.redrawOptions.setStatus("polyline", next);
        this.selector.handleTogglePolyline(next);
      },
    });
    // クラスター表示切替
    groups.redrawOptions.setButtonHandler("cluster", {
      onClick: () => {
        const current = groups.redrawOptions.getStatus("cluster");
        const next = current === "on" ? "off" : "on";
        groups.redrawOptions.setStatus("cluster", next);
        this.selector.handleToggleCluster(next);
      },
    });
    // 境界線表示切替
    groups.redrawOptions.setButtonHandler("boundary", {
      onClick: () => {
        const current = groups.redrawOptions.getStatus("boundary");
        const next = current === "on" ? "off" : "on";
        groups.redrawOptions.setStatus("boundary", next);
        this.selector.handleToggleBoundary(next);
      },
    });

    // --- GPX関連グループ ---
    // GPX追加（ファイル入力）
    groups.gpxOptions.setButtonHandler("gpxLoad", {
      cndFileInput: true, // クリック時にファイル選択を開く
      onFile: (map, file) => {
        this.selector.handleGpxLoad(file);
      },
    });
    // GPX保存
    groups.gpxOptions.setButtonHandler("gpxSave", {
      onClick: () => {
        this.selector.handleGpxSave();
      },
    });

    // --- 更新・クリア関連グループ ---
    // 経路更新（rerouteButton）
    groups.updateOptions.setButtonHandler("routeUpdate", {
      onClick: () => {
        this.selector.reorderMarkers();
      },
    });
    // 住所更新（addressUpButton）
    groups.updateOptions.setButtonHandler("addrUpdate", {
      onClick: () => {
        this.selector.reFetchAllAddresses();
      },
    });
    // クリア（clearButton）
    groups.updateOptions.setButtonHandler("clear", {
      onClick: () => {
        this.selector.clearMarkers();
      },
    });
  }
}
