/**
 * Leaflet Coordinate & Distance Control
 * 表示機能に特化し、特定のデータソースには依存しない
 */
export function initCoordinateControl() {
  if (L.Control.CoordinateDistance) return;

  L.Control.CoordinateDistance = L.Control.extend({
    options: {
      position: "bottomleft",
    },

    onAdd: function (map) {
      // コンテナ作成
      this._container = L.DomUtil.create(
        "div",
        "leaflet-control-mouseposition"
      );
      
      // スタイル調整（必要に応じてCSSファイルへ）
      this._container.style.backgroundColor = "rgba(255, 255, 255, 0.8)";
      this._container.style.padding = "5px 10px";
      this._container.style.fontSize = "12px";
      this._container.style.border = "1px solid #ccc";

      this._coordDiv = L.DomUtil.create("div", "", this._container);
      this._coordDiv.innerHTML = "— , —";
      
      this._distDiv = L.DomUtil.create("div", "", this._container);
      this._distDiv.style.fontWeight = "bold";
      this._distDiv.style.color = "#ff6600";
      this._distDiv.innerHTML = "0.00 km";

      // マウス移動イベントの登録
      map.on("mousemove", this._onMouseMove, this);

      // Leaflet特有の伝搬停止
      L.DomEvent.disableClickPropagation(this._container);
      L.DomEvent.disableScrollPropagation(this._container);

      return this._container;
    },

    onRemove: function (map) {
      map.off("mousemove", this._onMouseMove, this);
    },

    _onMouseMove: function (e) {
      this._coordDiv.innerHTML = `${e.latlng.lat.toFixed(5)}, ${e.latlng.lng.toFixed(5)}`;
    },

    /**
     * 外部から距離（メートル）を更新する
     * @param {number} meters 
     */
    updateDistance: function (meters) {
      if (!this._distDiv) return;
      const km = (meters || 0) / 1000;
      this._distDiv.innerHTML = `${km.toFixed(2)} km`;
    },
  });

  // ショートカット関数の登録
  L.control.coordinateDistance = function (options) {
    return new L.Control.CoordinateDistance(options);
  };
}