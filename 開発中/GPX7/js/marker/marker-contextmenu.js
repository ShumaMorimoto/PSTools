// marker-contextmenu.js
export default class MarkerContextMenu {
  constructor(handler, core) {
    this.handler = handler;
    this.core = core;
  }

  bindContextMenu(m) {
    // すでにバインド済みならスキップ
    if (m._contextMenuBound) {
      return; // すでにバインドされているので何もしない
    }

    // unbindを試みる（念のため）
    m.unbindContextMenu();

    m.bindContextMenu({
      contextmenu: true,
      contextmenuItems: [
        { text: "🗑 マーカー削除", callback: (e) => this._deleteMarker(e) },
        { text: "✂ ルート分割", callback: (e) => this._splitRoute(e) },
        { text: "🚩 始点設定", callback: (e) => this._setAsStart(e) },
        { text: "📍 座標コピー", callback: (e) => this._copyLatLng(e) },
        { text: "🏠 住所更新", callback: (e) => this._updateAddress(e) },
        { text: "✏️ 属性編集", callback: (e) => this._editAttributes(e) },
        { text: "🗺 境界表示", callback: (e) => this._showBoundary(e) },
      ],
    });

    // フラグを設定して次回の重複を防ぐ
    m._contextMenuBound = true;
  }

  // --- コールバック（中身は空でOK） ---
  _deleteMarker(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.core.removeMarker(m);
    this.handler.redraw();
  }
  _splitRoute(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.core.removeMarker(m, true);
    this.handler.redraw();
  }

  _setAsStart(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.core.jumpMarker(m);
    this.handler.redraw();
  }

  _addAsWaypoint(e) {}

  _copyLatLng(e) {
    const m = e.relatedTarget; // 右クリックされた Marker
    const { lat, lng } = m.getLatLng();
    const text = `${lat},${lng}`;

    navigator.clipboard
      .writeText(text)
      .then(() => {
        console.log("Copied:", text);
      })
      .catch((err) => {
        console.error("Clipboard copy failed:", err);
      });
  }

  _updateAddress(e) {}
  _editAttributes(e) {}
  _showBoundary(e) {}
  _duplicateMarker(e) {}
  _lockMarker(e) {}
  _openInfoPanel(e) {}
}
