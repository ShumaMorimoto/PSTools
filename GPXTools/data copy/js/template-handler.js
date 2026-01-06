export default class XxxHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle:      { label: "開始",   canCancel: false },
    selecting: { label: "選択中", canCancel: true  },
    preview:   { label: "確定",   canCancel: true  },
  };

  constructor(selector) {
    this.selector = selector;
    this.state = XxxHandler.State.IDLE;

    this.tempData = null;
    this.previewLayer = null;
  }

  // ---------------------------------------------------
  // 初期化（必要なら override）
  // ---------------------------------------------------
  init() {
    // 何もない場合は空実装
  }

  // ---------------------------------------------------
  // ボタン押下
  // ---------------------------------------------------
  onActionButtonClick() {
    switch (this.state) {
      case XxxHandler.State.IDLE:
        this._start();
        break;

      case XxxHandler.State.SELECTING:
        this._preview();
        break;

      case XxxHandler.State.PREVIEW:
        this._confirm();
        break;
    }
  }

  // ---------------------------------------------------
  // キャンセル（STATE → MODE）
  // ---------------------------------------------------
  handleCancel() {
    this.changeState(XxxHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // Map click（必要なら override）
  // ---------------------------------------------------
  handleMapClick(e) {}

  // ---------------------------------------------------
  // Marker click（必要なら override）
  // ---------------------------------------------------
  handleMarkerClick(e, marker) {
    switch (this.state) {
      case XxxHandler.State.SELECTING:
        this.tempData = marker;
        this.changeState(XxxHandler.State.PREVIEW);
        break;

      case XxxHandler.State.PREVIEW:
        this.handleCancel();
        break;
    }
  }

  // ---------------------------------------------------
  // 状態遷移（STATE → UIManager）
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    switch (newState) {
      case XxxHandler.State.IDLE:
        this._clear();
        break;

      case XxxHandler.State.SELECTING:
        this._prepareSelecting();
        break;

      case XxxHandler.State.PREVIEW:
        this._preparePreview();
        break;
    }

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...XxxHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // 内部ロジック
  // ---------------------------------------------------
  _start() {
    this.selector.setMode(this.selector.constructor.Mode.XXX_MODE);
    this.changeState(XxxHandler.State.SELECTING);
  }

  _preview() {
    this.changeState(XxxHandler.State.PREVIEW);
  }

  _confirm() {
    this.changeState(XxxHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  _clear() {
    this.tempData = null;
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
  }

  _prepareSelecting() {
    this.tempData = null;
  }

  _preparePreview() {
    if (this.tempData) {
      // previewLayer を作る（必要なら override）
    }
  }
}