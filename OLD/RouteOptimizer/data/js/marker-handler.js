// marker-handler.js

export default class MarkerHandler {
  constructor(selector, gpxService) {
    this.selector = selector;
    this.gpxService = gpxService;

    this.markers = [];
    this.pointList = [];
    this.selectedIndex = null;
    this.requestSeq = 0;
  }

  initMarkers() {
    // 初期ポイントを描画
    this.selector.initialPoints.forEach((p) => this.addPoint(p));

    // ✅ GPX入力ハンドラ（ファイル読み込み）
    document
      .getElementById(this.selector.controls.gpxInputId)
      .addEventListener("change", (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
          const gpxText = event.target.result;
          this.loadGpx(gpxText);   // ✅ GPXService を使う
          e.target.value = "";
        };
        reader.readAsText(file);
      });
  }

  // -----------------------------
  // ✅ GPX 読み込み（既存マーカーを消さずに追加）
  // -----------------------------
  loadGpx(gpxText) {
    const points = this.gpxService.parseGpx(gpxText);

    points.forEach((p) => {
      this.addPoint(p);

      // 住所補完（必要なら）
      const marker = this.markers[this.markers.length - 1];
      this.selector.fetchAddressAsync(p, marker);
    });

    // 最初の GPX ポイントにズーム（任意）
    if (points.length > 0) {
      this.selector.map.setView([points[0].lat, points[0].lon], 14);
    }
  }

  // -----------------------------
  // ✅ GPX 保存（pointList → GPX）
  // -----------------------------
  exportGpx() {
    return this.gpxService.generateGpx(this.pointList);
  }

  // -----------------------------
  // マーカー追加
  // -----------------------------
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

      try { m.setIcon(icon); } catch (e) {}
      try { m.setZIndexOffset(isSelected ? 1000 : 0); } catch (e) {}
    });
  }
}