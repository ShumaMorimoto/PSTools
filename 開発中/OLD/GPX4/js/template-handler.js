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
  // 状態遷移（Old は見ない）
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    switch (newState) {
      case XxxHandler.State.IDLE:
        this._clear();
        break;

      case XxxHandler.State.SELECTING:
        this._prepareForSelecting();
        break;

      case XxxHandler.State.PREVIEW:
        this._prepareForPreview();
        break;
    }

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...XxxHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // 以下は Handler の内部ロジック
  // ---------------------------------------------------
  _start() {
    this.selector.setMode(this.selector.constructor.Mode.XXX_MODE);
    this.changeState(XxxHandler.State.SELECTING);
  }

  _preview() {
    // preview logic
    this.changeState(XxxHandler.State.PREVIEW);
  }

  _confirm() {
    // commit logic
    this.changeState(XxxHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  _clear() {
    // clear preview, temp data, etc.
  }

  _prepareForSelecting() {
    // init selecting
  }

  _prepareForPreview() {
    // init preview
  }
}