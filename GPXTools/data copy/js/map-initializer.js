// map-initializer.js

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
    // ★ SearchService を Leaflet UI に接続（正しい場所）
    // ----------------------------------------
    if (this.selector.searchService) {
      const searchControl = new window.GeoSearch.GeoSearchControl({
        provider: {
          search: (query) => this.selector.searchService.search(query),
        },
        style: "button",
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
        // updateHistory → showLocation に変更
        this.selector.searchService.showLocation(trkpt);
      });
    }

    // ----------------------------------------
    // 座標表示
    // ----------------------------------------
    if (L.Control) {
      L.Control.coordinates = L.Control.extend({
        onAdd: function (map) {
          const div = L.DomUtil.create("div", "coordinate-display");
          div.style.background = "transparent";
          div.style.border = "none";
          div.style.padding = "4px 8px";
          div.style.fontSize = "20px";
          div.style.fontWeight = "600";
          div.style.color = "#1e88e5";
          div.style.textShadow = "0 0 3px rgba(255,255,255,0.8)";
          div.style.margin = "4px";
          div.innerHTML = " - , - ";

          map.on("mousemove", (e) => {
            div.innerHTML = `${e.latlng.lat.toFixed(6)}, ${e.latlng.lng.toFixed(
              6
            )}`;
          });

          return div;
        },
      });

      L.control.coordinates = function (opts) {
        return new L.Control.coordinates(opts);
      };

      L.control.coordinates({ position: "topright" }).addTo(this.selector.map);
    }

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

    // ----------------------------------------
    // 地図クリック → Selector に通知
    // ----------------------------------------
    this.selector.map.on("click", (e) => {
      this.selector.handleMapClick(e);
    });

    // ----------------------------------------
    // Polyline / Cluster トグル
    // ----------------------------------------
    L.Control.LayerToggle = L.Control.extend({
      onAdd: function (map) {
        const container = L.DomUtil.create("div", "leaflet-bar layer-toggle");

        container.innerHTML = `
          <a href="#" id="polylineToggleBtn" class="toggle-btn">
            <i class="fas fa-route"></i>
          </a>
          <a href="#" id="clusterToggleBtn" class="toggle-btn">
            <i class="fas fa-braille"></i>
          </a>
          <a href="#" id="boundaryToggleBtn" class="toggle-btn">
            <i class="fas fa-draw-polygon"></i>
          </a>
        `;

        L.DomEvent.disableClickPropagation(container);
        return container;
      },
    });

    L.control.layerToggle = function (opts) {
      return new L.Control.LayerToggle(opts);
    };

    L.control.layerToggle({ position: "topleft" }).addTo(this.selector.map);

    // ----------------------------------------
    // UI → Handler 通知
    // ----------------------------------------
    document
      .getElementById("polylineToggleBtn")
      .addEventListener("click", () => {
        this.selector.handleTogglePolyline();
        document.getElementById("polylineToggleBtn").classList.toggle("active");
      });
    document.getElementById("polylineToggleBtn").classList.add("active");

    document
      .getElementById("clusterToggleBtn")
      .addEventListener("click", () => {
        this.selector.handleToggleCluster();
        document.getElementById("clusterToggleBtn").classList.toggle("active");
      });
    // ★ 追加：Boundary トグル
    document
      .getElementById("boundaryToggleBtn")
      .addEventListener("click", () => {
        this.selector.handleToggleBoundary();
        document.getElementById("boundaryToggleBtn").classList.toggle("active");
      });
  }
}
