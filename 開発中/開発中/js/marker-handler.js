// marker-handler.js

export default class MarkerHandler {
  constructor(selector, gpxService) {
    this.selector = selector;
    this.gpxService = gpxService;

    this.markers = [];
    this.selectedMarkers = [];
    this.requestSeq = 0;
  }

  // -----------------------------
  // 初期化
  // -----------------------------
  initMarkers() {
    this.selector.initialPoints.forEach((p) => {
      this.addPoint(p);
    });
  }

  // -----------------------------
  // マーカー追加（クリック追加と GPX
  // -----------------------------
  addPoint(info) {
    // ✅ 永続 Model の trkpt（本物の tp）が返る
    const tp = this.gpxService.addTrkpt(
      info.lat,
      info.lon,
      info.name,
      info.desc
    );

    // ✅ Marker を作る
    const m = this._createMarker(tp);

    // ✅ fetchAddressAsync に “本物の tp” を渡す
    this.selector.fetchAddressAsync(tp, m, this);

    this.selector.uiManager.updateListUI();
    this.renumberMarkers();
    this.debugModel();

    return tp;
  }

  // -----------------------------
  // マーカー生成
  // -----------------------------
  _createMarker(tp) {
    const idx = this.markers.length;

    const icon = L.ExtraMarkers.icon({
      icon: "fa-number",
      number: idx + 1,
      markerColor: "blue",
      shape: "circle",
    });

    const m = L.marker([tp.lat, tp.lon], {
      draggable: true,
      icon: icon,
    }).addTo(this.selector.map);

    // ✅ 左クリック（単一 or 追加）
    m.on("click", (e) => {
      if (e.originalEvent.shiftKey || e.originalEvent.ctrlKey) {
        if (!this.selectedMarkers.includes(m)) {
          this.selectedMarkers.push(m);
        }
      } else {
        this.selectedMarkers = [m];
      }

      this.selector.uiManager.updateListUI();
      this.renumberMarkers();
    });

    // ✅ 右クリック → 削除
    m.on("contextmenu", () => {
      const idx = this.markers.indexOf(m);
      if (idx === -1) return;

      this.selector.map.removeLayer(m);
      this.markers.splice(idx, 1);
      this.selectedMarkers = this.selectedMarkers.filter((sel) => sel !== m);

      this.gpxService.removeTrkpt(idx);

      this.selector.uiManager.updateListUI();
      this.renumberMarkers();
      this.debugModel();
    });

    // ✅ ドラッグ → 位置更新
    m.on("dragend", (e) => {
      const idx = this.markers.indexOf(m);
      const latlng = e.target.getLatLng();

      this.gpxService.updateTrkpt(idx, {
        lat: latlng.lat,
        lon: latlng.lng,
      });

      const point = this.gpxService.getTrkptList()[idx];
      this.selector.fetchAddressAsync(point, m, this);

      this.selector.uiManager.updateListUI();
      this.debugModel();
    });

    this.markers.push(m);
  }

  // -----------------------------
  // マーカー番号・色の再計算
  // -----------------------------
  renumberMarkers() {
    this.markers.forEach((m, i) => {
      const isSelected = this.selectedMarkers.includes(m);

      const icon = L.ExtraMarkers.icon({
        icon: "fa-number",
        number: i + 1,
        markerColor: isSelected ? "red" : "blue",
        shape: "circle",
      });

      m.setIcon(icon);
    });
  }

  // -----------------------------
  // デバッグ用
  // -----------------------------
  debugModel() {
    console.log("GPXModel:", this.gpxService.getModel());
  }
}
