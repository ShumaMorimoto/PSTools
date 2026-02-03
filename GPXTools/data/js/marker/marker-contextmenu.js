// marker-contextmenu.js

import { notify } from "./../api-utils.js";

export default class MarkerContextMenu {
  constructor(handler) {
    this.handler = handler;
  }

  /**
   * 通常マーカー用バインド
   */
  bindMarker(m) {
    const items = [
      { text: "🗑 マーカー削除", callback: (e) => this._deleteMarker(e) },
      { text: "✂ ルート分割", callback: (e) => this._splitRoute(e) },
      { text: "🚩 始点設定", callback: (e) => this._setAsStart(e) },
    ];
    this._bindCommon(m, "📌", items);
  }

  /**
   * しるし（Indicator）用バインド
   */
  bindIndicator(m) {
    const items = [
      {
        text: "🗑 しるしを消去",
        callback: () => this.handler.indicator.clear(),
      },
      {
        text: "➕ 地点を登録",
        callback: () => this.handler.indicator.refreshPopup(),
      },
    ];
    this._bindCommon(m, "📍", items);
  }

  /**
   * 内部共通ロジック：座標コピーなどの共通項目を付与してバインド
   * @param {L.Marker} m - 対象オブジェクト
   * @param {string} symbol - 表示用アイコン (📌 or 📍)
   * @param {Array} specificItems - 個別のメニュー項目
   */
  _bindCommon(m, symbol, specificItems) {
    if (m._contextMenuBound) return;
    if (typeof m.unbindContextMenu === "function") m.unbindContextMenu();

    const { lat, lng } = m.getLatLng();

    m.bindContextMenu({
      contextmenu: true,
      contextmenuItems: [
        {
          text: `${symbol} ${lat.toFixed(5)}, ${lng.toFixed(5)}`,
          callback: (e) => this._copyLatLng(e),
        },
        { separator: true },
        ...specificItems,
      ],
    });

    m._contextMenuBound = true;
  }

  // --- ハンドラメソッド群 (共通利用) ---

  _copyLatLng(e) {
    const m = e.relatedTarget;
    const { lat, lng } = m.getLatLng();
    navigator.clipboard
      .writeText(`${lat},${lng}`)
      .then(() => notify("📋 座標をコピーしました"));
  }

  _deleteMarker(e) {
    this.handler.removeMarker(e.relatedTarget);
  }

  _splitRoute(e) {
    this.handler.removeMarker(e.relatedTarget, true);
  }

  async _setAsStart(e) {
    const m = e.relatedTarget;
    this.handler.jumpMarker(m);
    await this.handler.reorderMarkers();
  }
}
