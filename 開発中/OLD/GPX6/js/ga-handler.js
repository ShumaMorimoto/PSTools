import { callApi, pollApi } from "/runapp/lib/js/api.js";

export default class GAHandler {
  static State = {
    IDLE: "idle",
    RUNNING: "running", // ← SELECTING 相当
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle: { label: "最適化", canCancel: false },
    running: { label: "停止", canCancel: true },
    preview: { label: "反映", canCancel: true },
  };

  constructor(selector) {
    this.selector = selector;
    this.gpxService = selector.gpxService;

    this.state = GAHandler.State.IDLE;
    this.stopPolling = null;
  }

  init() {}

  // ---------------------------------------------------
  // ボタン押下
  // ---------------------------------------------------
  onActionButtonClick() {
    switch (this.state) {
      case GAHandler.State.IDLE:
        this._start();
        break;

      case GAHandler.State.RUNNING:
        this._stop();
        break;

      case GAHandler.State.PREVIEW:
        this._confirm();
        break;
    }
  }

  // ---------------------------------------------------
  // キャンセル
  // ---------------------------------------------------
  async handleCancel() {
    if (this.state === GAHandler.State.IDLE) return;

    // RUNNING 中なら Stop
    if (this.state === GAHandler.State.RUNNING) {
      await this._stop();
    }
    // MarkerHandler に復元させる
    this.selector.cancelReorder();
    this.changeState(GAHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // 地図クリック
  // ---------------------------------------------------
  handleMapClick(e) {
    return;
  }

  // ---------------------------------------------------
  // 状態遷移
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...GAHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // IDLE → RUNNING
  // ---------------------------------------------------
  async _start() {
    // 並び替えセッション開始（スナップショットを取る）
    const snapshot = this.selector.startReorderSession();

    // ★ build のロジックでコンバートしたデータを渡す
    const input = snapshot.map((p) => ({
      lat: p.lat,
      lon: p.lon,
    }));

    await callApi("Start", input);

    // ポーリング開始
    if (this.stopPolling) this.stopPolling();
    this.stopPolling = pollApi("Status", 1000, (st) => this._onStatus(st));

    this.selector.setMode(this.selector.constructor.Mode.GA_MODE);
    this.changeState(GAHandler.State.RUNNING);
  }

  // ---------------------------------------------------
  // RUNNING → PREVIEW
  // ---------------------------------------------------
  async _stop() {
    await callApi("Stop");

    if (this.stopPolling) {
      this.stopPolling();
      this.stopPolling = null;
    }

    this.changeState(GAHandler.State.PREVIEW);
  }

  // ---------------------------------------------------
  // PREVIEW → IDLE（確定）
  // ---------------------------------------------------
  _confirm() {
    const indices = this.selector.getLatestReorderIndices();
    if (!indices) {
      console.warn("No latest indices to apply.");
      return;
    }
    // MarkerHandler に確定させる
    this.selector.confirmReorder(indices);

    this.changeState(GAHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // Status Polling
  // ---------------------------------------------------
  _onStatus(status) {
    if (!status?.Result) return;

    const routeIndices = status.Result.Route;
    if (!routeIndices) return;

    // PREVIEW 適用は MarkerHandler に任せる
    this.selector.applyReorder(routeIndices);
  }
}
