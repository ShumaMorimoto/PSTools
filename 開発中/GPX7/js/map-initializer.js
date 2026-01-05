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
      status: "idle",
      icon: '<i class="fas fa-image"></i>',
      title: "画像追加",
      fileInput: false, // ← これが正しい
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

    // カスタムLeafletコントロールの定義（新しいクラスとして追加）
    L.Control.Search = L.Control.extend({
      options: {
        position: "topleft", // デフォルト位置（必要に応じて変更）
        searchService: null, // SearchServiceインスタンスを渡す
        handleShowLocation: null, // 場所表示ハンドラを渡す
      },

      initialize: function (options) {
        L.setOptions(this, options);
        if (!this.options.searchService || !this.options.handleShowLocation) {
          throw new Error(
            "searchService and handleShowLocation are required options."
          );
        }
      },

      onAdd: function (map) {
        this._map = map; // マップ参照を保持

        // コントロールのコンテナ作成
        const container = L.DomUtil.create(
          "div",
          "leaflet-bar leaflet-control leaflet-control-search"
        );

        // 入力フィールド作成
        const input = L.DomUtil.create("input", "search-input", container);
        input.id = "autoCompleteSearch";
        input.type = "text";
        input.placeholder = "場所を検索...";

        // マップイベントの干渉を防ぐ
        L.DomEvent.disableClickPropagation(container);
        L.DomEvent.on(container, "mousewheel", L.DomEvent.stopPropagation);

        // autoComplete.jsの初期化を遅らせる（DOM追加後）
        setTimeout(() => {
          this.autoCompleteInstance = new autoComplete({
            selector: "#autoCompleteSearch",
            placeHolder: "場所を検索...",
            data: {
              src: async (query) => {
                // SearchServiceのsearchを呼び出し
                const results = await this.options.searchService.search({
                  query,
                });
                return results;
              },
              keys: ["label"], // 検索キー（labelで検索）
              cache: false, // キャッシュ無効（履歴が動的に変わるため）
            },
            threshold: 1, // 1文字からトリガー
            debounce: 200, // 200msのデバウンス
            resultsList: {
              noResults: true, // 結果なしの場合表示
              maxResults: 10, // 最大結果数
            },
            resultItem: {
              highlight: true, // ハイライト有効
            },
          });

          // 選択イベントハンドリング
          input.addEventListener("selection", (event) => {
            const feedback = event.detail;
            const selection = feedback.selection.value; // 選択されたオブジェクト {label, x, y, raw, ...}

            // 仮マーカー生成（UI層の責務）
            this.options.handleShowLocation(selection.raw);

            // 履歴更新（Service の責務）
            this.options.searchService.showLocation(selection.raw);

            // 入力フィールドをクリア（オプション）
            input.value = "";
          });
        }, 0);

        return container;
      },

      onRemove: function (map) {
        // クリーンアップ（必要に応じて）
        if (this.autoCompleteInstance) {
          // autoComplete.jsの破棄（ドキュメント参照、必要に応じて）
        }
      },
    });

    // コントロールのインスタンス化と追加（元のコードの置き換え）
    const searchControl = new L.Control.Search({
      searchService: this.selector.searchService,
      handleShowLocation: this.selector.handleShowLocation,
    });

    this.selector.map.addControl(searchControl);

    // 元のgeosearchイベントは不要になるため削除
    // this.selector.map.on("geosearch/showlocation", ...) は削除
    // -------------------------
    // ---------------
    // ★ SearchService を Leaflet UI に接続（正しい場所）
    // ----------------------------------------
    /*     if (this.selector.searchService) {
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
    } */

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
  }
}
