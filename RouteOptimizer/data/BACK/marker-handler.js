// marker-handler.js

export default class MarkerHandler {
  constructor(selector) {
    this.selector = selector;
    this.markers = [];
    this.pointList = [];
    this.selectedIndex = null;
    this.requestSeq = 0;
  }

  initMarkers() {
    this.selector.initialPoints.forEach((p) => this.addPoint(p));
    // GPX入力ハンドラの追加（MAP表示後、ボタンでファイル読み込み）
    document
      .getElementById(this.selector.controls.gpxInputId)
      .addEventListener("change", (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (event) => {
          this.loadGpxFromFile(event.target.result);
          e.target.value = "";
        };
        reader.readAsText(file);
      });
  }
  
  loadGpxFromFile(gpxContent) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(gpxContent, "text/xml");

    const trkpts = xmlDoc.getElementsByTagName("trkpt");
    for (let i = 0; i < trkpts.length; i++) {
      const lat = parseFloat(trkpts[i].getAttribute("lat"));
      const lon = parseFloat(trkpts[i].getAttribute("lon"));
      if (!isNaN(lat) && !isNaN(lon)) {
        const info = {
          lat,
          lon,
          name: `GPX Point ${i + 1}`,
          desc: "",
          extended: {},
        };
        this.addPoint(info); // 既存ポイントを保持して追加

        const newMarker = this.markers[this.markers.length - 1];
        this.selector.fetchAddressAsync(info, newMarker);
      }
    }

    // 最初のGPXポイントにズーム（オプション）
    if (trkpts.length > 0) {
      const firstLat = parseFloat(trkpts[0].getAttribute("lat"));
      const firstLon = parseFloat(trkpts[0].getAttribute("lon"));
      this.selector.map.setView([firstLat, firstLon], 14);
    }
  }

  addPoint(info) {
    this.pointList.push(info);
    const idx = this.pointList.length - 1;

    const icon = L.ExtraMarkers.icon({
      icon: "fa-number",
      number: this.pointList.length,
      markerColor: "blue",
      shape: "circle",
    });

    const m = L.marker([info.lat, info.lon], {
      draggable: true,
      icon: icon,
    }).addTo(this.selector.map);
    this.markers.push(m);

    m.on("click", (ev) => {
      L.DomEvent.stopPropagation(ev);
      this.selectMarker(idx);
    });

    m.on("contextmenu", () => {
      this.removeMarker(idx);
    });

    m.on("dragend", () => {
      const pos = m.getLatLng();
      this.pointList[idx].lat = pos.lat;
      this.pointList[idx].lon = pos.lng;
      this.selector.uiManager.updateListUI();
      this.selector.fetchAddressAsync(this.pointList[idx], m);
    });

    this.selector.uiManager.updateListUI();
    this.renumberMarkers();
  }

  selectMarker(index) {
    this.selectedIndex = index;
    document.getElementById(this.selector.controls.pointListId).value = index;
    this.renumberMarkers();
  }

  removeMarker(index) {
    if (this.markers[index]) this.selector.map.removeLayer(this.markers[index]);
    this.markers.splice(index, 1);
    this.pointList.splice(index, 1);

    this.selectedIndex = null;
    this.selector.uiManager.updateListUI();
    this.renumberMarkers();
  }

  clearMarkers() {
    this.markers.forEach((m) => {
      if (m) this.selector.map.removeLayer(m);
    });
    this.markers = [];
    this.pointList = [];
    this.selectedIndex = null;
    this.selector.uiManager.updateListUI();
  }

  renumberMarkers() {
    this.markers.forEach((m, i) => {
      const isSelected = i === this.selectedIndex;
      const icon = L.ExtraMarkers.icon({
        icon: "fa-number",
        number: i + 1,
        markerColor: isSelected ? "red" : "blue",
        shape: "circle",
      });
      try {
        m.setIcon(icon);
      } catch (e) {
        /* ignore */
      }
      try {
        m.setZIndexOffset(isSelected ? 1000 : 0);
      } catch (e) {
        /* ignore */
      }
    });
  }
}
