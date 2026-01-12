// marker-polyline.js
export default class MarkerPolyline {
  constructor(handler) {
    this.handler = handler;
    this.show = true;
    this.polyline = L.polyline([], { color: "#ff8800", weight: 3 });

    // --- 追加: イベントを購読する ---
    // リスト構造が変わった（追加・削除・並び替え）時に redraw を実行
    markerEvents.addEventListener(MarkerEventTypes.LIST_CHANGED, () => {
      this.redraw();
    });

    // 座標が動いた時にも線を引き直す必要がある場合
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, () => {
      this.redraw();
    });
  }

  render() {
    const latlngs = this.handler.getMarkers().map(({ m }) => m.getLatLng());
    this.polyline.setLatLngs(latlngs);

    if (!this.handler.map.hasLayer(this.polyline)) {
      this.polyline.addTo(this.handler.map);
    }
  }

  clear() {
    if (this.handler.map.hasLayer(this.polyline)) {
      this.handler.map.removeLayer(this.polyline);
    }
  }
}
