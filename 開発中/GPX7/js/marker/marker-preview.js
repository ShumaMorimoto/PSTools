// marker-preview.js
export default class MarkerPreview {
  constructor(selector, handler) {
    this.selector = selector;
    this.handler = handler;
    this.previewMarkers = [];
  }

  add(trkpt) {
    const pm = this._createPreviewMarker(trkpt);
    this.previewMarkers.push(pm);
    return pm;
  }

  _createPreviewMarker(trkpt) {
    const center = [trkpt.lat, trkpt.lon];
    const keyword = trkpt.extensions?.keyword ?? trkpt.name ?? "";

    const previewIcon = L.divIcon({
      className: "preview-marker",
      html: `<div style="
        width:24px;
        height:24px;
        border-radius:50%;
        background: rgba(255, 80, 80, 0.8);
        border: 2px solid #900;
        box-shadow: 0 0 4px rgba(0,0,0,0.6);
      "></div>`,
      iconSize: [24, 24],
      iconAnchor: [12, 12],
    });

    const pm = L.marker(center, {
      draggable: true,
      icon: previewIcon,
    }).addTo(this.selector.map);

    this.selector.map.setView(center, 16);

    pm._keyword = keyword;

    const btnId = "confirm-" + Date.now();
    pm.bindPopup(`
      <strong>仮マーカー</strong><br>
      Keyword: ${keyword}<br>
      <button id="${btnId}">この地点を登録</button>
    `);

    pm.on("popupopen", () => {
      document.getElementById(btnId).onclick = () => {
        this.confirm(pm);
      };
    });

    pm.on("dragend", (e) => {
      const newPos = e.target.getLatLng();
      pm.setLatLng(newPos);
    });

    pm._timer = setTimeout(() => {
      this.remove(pm);
    }, 3 * 60 * 1000);

    return pm;
  }

  confirm(pm) {
    const pos = pm.getLatLng();

    this.handler.addPoint({
      lat: pos.lat,
      lon: pos.lng,
      extensions: { keyword: pm._keyword },
    });

    this.remove(pm);
  }

  remove(pm) {
    clearTimeout(pm._timer);
    this.selector.map.removeLayer(pm);
    this.previewMarkers = this.previewMarkers.filter((x) => x !== pm);
  }

  clear() {
    this.previewMarkers.forEach((pm) => {
      clearTimeout(pm._timer);
      this.selector.map.removeLayer(pm);
    });
    this.previewMarkers = [];
  }
}
