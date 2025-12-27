export default class SplitHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PREVIEW: "preview",
  };

  constructor(selector) {
    this.selector = selector;
    this.state = SplitHandler.State.IDLE;

    this.selectedMarker = null;
    this.highlightLayer = null;
  }

  // ---------------------------------------------------
  // ボタン押下
  // ---------------------------------------------------
  onSplitButtonClick() {
    switch (this.state) {
      case SplitHandler.State.IDLE:
        this._enterSelectingMode();
        break;

      case SplitHandler.State.SELECTING:
        console.warn("⚠ マーカーを選択してください");
        break;

      case SplitHandler.State.PREVIEW:
        this._commitSplit();
        break;
    }
  }

  // ---------------------------------------------------
  // キャンセル
  // ---------------------------------------------------
  onCancel() {
    if (this.state === SplitHandler.State.IDLE) return;

    this._clearPreview();
    this.state = SplitHandler.State.IDLE;
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this.selector.updateModeUI();
    this._updateButtonLabel("経路分割");
  }

  canCancel() {
    return this.state !== SplitHandler.State.IDLE;
  }

  // ---------------------------------------------------
  // 地図クリック（Split モードでは無視）
  // ---------------------------------------------------
  handleMapClick(e) {
    // Split モードはマーカークリックのみ扱う
  }

  // ---------------------------------------------------
  // マーカークリック
  // ---------------------------------------------------
  handleMarkerClick(marker) {
    if (this.state !== SplitHandler.State.SELECTING) return;

    this.selectedMarker = marker;
    this._previewMarker(marker);

    this.state = SplitHandler.State.PREVIEW;
    this._updateButtonLabel("分割確定");
  }

  // ---------------------------------------------------
  // SELECTING モードへ
  // ---------------------------------------------------
  _enterSelectingMode() {
    console.log("[SplitHandler] IDLE → SELECTING");

    this.selector.currentMode = this.selector.constructor.Mode.SPLIT_MODE;
    this.selector.updateModeUI();

    this.state = SplitHandler.State.SELECTING;
    this._updateButtonLabel("マーカー選択");

    console.log(
      "✂️ 経路分割モード：分割したい位置のマーカーをクリックしてください"
    );
  }

  // ---------------------------------------------------
  // PREVIEW：選択マーカーをハイライト
  // ---------------------------------------------------
  _previewMarker(marker) {
    this._clearPreview();

    this.highlightLayer = L.circleMarker(marker.getLatLng(), {
      radius: 10,
      color: "red",
      weight: 3,
    }).addTo(this.selector.map);

    console.log("👁️ マーカーを選択しました");
  }

  // ---------------------------------------------------
  // PREVIEW → IDLE：分割実行
  // ---------------------------------------------------
  _commitSplit() {
    if (!this.selectedMarker) return;
    this.selector.markerHandler.removeMarker(this.selectedMarker, true);
    this._resetAll();
  }

  // ---------------------------------------------------
  // UI 更新
  // ---------------------------------------------------
  _updateButtonLabel(label) {
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.splitActionBtnId,
      label
    );
  }

  _clearPreview() {
    if (this.highlightLayer) {
      this.selector.map.removeLayer(this.highlightLayer);
      this.highlightLayer = null;
    }
  }

  _resetAll() {
    this._clearPreview();
    this.state = SplitHandler.State.IDLE;
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this.selector.updateModeUI();
    this._updateButtonLabel("経路分割");
  }
}
