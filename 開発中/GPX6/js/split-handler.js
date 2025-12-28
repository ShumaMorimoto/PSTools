export default class SplitHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle: { label: "経路分割", canCancel: false },
    selecting: { label: "拠点選択", canCancel: true },
    preview: { label: "分割確定", canCancel: true },
  };

  constructor(selector) {
    this.selector = selector;
    this.state = SplitHandler.State.IDLE;

    this.selectedMarker = null;
    this.highlightLayer = null;
  }

  // ---------------------------------------------------
  // 初期化（必要なら）
  // ---------------------------------------------------
  init() {}

  // ---------------------------------------------------
  // ボタン押下（テンプレート準拠）
  // ---------------------------------------------------
  onActionButtonClick() {
    switch (this.state) {
      case SplitHandler.State.IDLE:
        this._start();
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
  // キャンセル（テンプレート準拠）
  // ---------------------------------------------------
  handleCancel() {
    this._clearPreview();
    this.changeState(SplitHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // Map click（Split は無視）
  // ---------------------------------------------------
  handleMapClick(e) {}

  // ---------------------------------------------------
  // Marker click
  // ---------------------------------------------------
  handleMarkerClick(e, marker) {
    if (this.state !== SplitHandler.State.SELECTING) return;

    this.selectedMarker = marker;
    this._previewMarker(marker);

    this.changeState(SplitHandler.State.PREVIEW);
  }

  // ---------------------------------------------------
  // 状態遷移（テンプレート準拠）
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    switch (newState) {
      case SplitHandler.State.IDLE:
        this._clearPreview();
        this.selectedMarker = null;
        break;

      case SplitHandler.State.SELECTING:
        this.selectedMarker = null;
        break;

      case SplitHandler.State.PREVIEW:
        // previewLayer は handleMarkerClick で作成済み
        break;
    }

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...SplitHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // 内部ロジック
  // ---------------------------------------------------
  _start() {
    this.selector.setMode(this.selector.constructor.Mode.SPLIT_MODE);
    this.changeState(SplitHandler.State.SELECTING);
  }

  _previewMarker(marker) {
    this._clearPreview();

    this.highlightLayer = L.circleMarker(marker.getLatLng(), {
      radius: 10,
      color: "red",
      weight: 3,
    }).addTo(this.selector.map);
  }

  _commitSplit() {
    if (!this.selectedMarker) return;

    this.selector.removeMarker(this.selectedMarker, true);

    this.changeState(SplitHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  _clearPreview() {
    if (this.highlightLayer) {
      this.selector.map.removeLayer(this.highlightLayer);
      this.highlightLayer = null;
    }
  }
}
