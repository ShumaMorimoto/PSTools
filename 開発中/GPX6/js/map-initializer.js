// map-initializer.js
export default class MapInitializer {
  constructor(selector) {
    this.selector = selector;
  }

  initMap() {
    // ✅ 地図生成
    this.selector.map = L.map(this.selector.mapId).setView(
      [this.selector.initialView[0], this.selector.initialView[1]],
      this.selector.initialView[2]
    );

    // ✅ タイル
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors",
      maxZoom: 19,
    }).addTo(this.selector.map);

    // ✅ Geocoder
    if (L.Control && L.Control.geocoder) {
      L.Control.geocoder({
        placeholder: "地名・住所を検索",
        defaultMarkGeocode: false,
        geocoder: L.Control.Geocoder.nominatim({
          geocodingQueryParams: {
            format: "json",
            addressdetails: 1,
            limit: 10,
            countrycodes: "jp",
          },
        }),
      })
        .on("markgeocode", (e) => {
          const g = e.geocode;
          const latlng = L.latLng(g.center.lat, g.center.lng);
          const html = `
    <b>${g.name}</b><br/>
    緯度: ${latlng.lat.toFixed(6)}<br/>
    経度: ${latlng.lng.toFixed(6)}<br/>
    <small>${g.html}</small>
  `;
          L.popup()
            .setLatLng(latlng)
            .setContent(html)
            .openOn(this.selector.map); // ← ✅ this.selector が正しく参照される
          this.selector.map.setView(latlng, 16);
        })
        .addTo(this.selector.map);

      //      L.Control.geocoder({ defaultMarkGeocode: false })
      //        .on("markgeocode", (e) => {
      //          this.selector.map.setView(e.geocode.center, 16);
      //        })
      //        .addTo(this.selector.map);
    }

    // ✅ Coordinate Control（Geocoder より先に追加）
    if (L.Control) {
      L.Control.coordinates = L.Control.extend({
        onAdd: function (map) {
          const div = L.DomUtil.create("div", "coordinate-display");
          div.style.background = "transparent";
          div.style.border = "none";
          div.style.padding = "4px 8px";
          div.style.fontSize = "20px";
          div.style.fontWeight = "600";
          div.style.color = "#1e88e5"; // ✅ 落ち着いた濃い青
          div.style.textShadow = "0 0 3px rgba(255,255,255,0.8)"; // ✅ 白の薄い縁取り
          div.style.margin = "4px";
          div.innerHTML = " - , - ";

          map.on("mousemove", (e) => {
            div.innerHTML =
              `${e.latlng.lat.toFixed(6)}, ` + `${e.latlng.lng.toFixed(6)}`;
          });

          return div;
        },
      });

      L.control.coordinates = function (opts) {
        return new L.Control.coordinates(opts);
      };

      L.control.coordinates({ position: "topright" }).addTo(this.selector.map);
    }

    // ✅ distortableCollection
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

    // ✅ 地図クリック → Selector に通知するだけ（旧ロック方式を廃止）
    this.selector.map.on("click", (e) => {
      this.selector.handleMapClick(e);
    });
  }
}
