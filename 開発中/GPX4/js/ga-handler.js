// ga-handler.js
import { callApi, pollApi } from "/runapp/lib/js/api.js";

export default class GAHandler {
  static State = {
    IDLE: "idle",
    RUNNING: "running",
    PREVIEW: "preview",
  };

  constructor(selector, gpxService) {
    this.selector = selector;
    this.gpxService = gpxService;

    this.state = GAHandler.State.IDLE;

    this.stopPolling = null;
    this.latestOrder = null;
    this.originalOrder = null;
  }

  // ---------------------------------------------------
  // GA ボタン
  // ---------------------------------------------------
  onGAButtonClick() {
    switch (this.state) {
      case GAHandler.State.IDLE:
        this.startGA();
        break;

      case GAHandler.State.RUNNING:
        this.stopGA();
        break;

      case GAHandler.State.PREVIEW:
        this.applyFinalResult();
        break;
    }
  }

  // ---------------------------------------------------
  // 地図クリック
  // ---------------------------------------------------
  handleMapClick(e) {
    switch (this.state) {
      case GAHandler.State.RUNNING:
        console.log("⚠ GA 実行中は地図クリック無効");
        break;

      case GAHandler.State.PREVIEW:
        console.log("🔄 GA PREVIEW → キャンセル");
        this.cancel();
        break;

      case GAHandler.State.IDLE:
      default:
        break;
    }
  }

  // ---------------------------------------------------
  // Start（callApi("Start")）
  // ---------------------------------------------------
  async startGA() {
    this.originalOrder = [...this.selector.markerHandler.markers];

    const input = this._buildInputData();
    const res = await callApi("Start", input);
    console.log("Start:", res);

    if (this.stopPolling) this.stopPolling();
    this.stopPolling = pollApi("Status", 1000, (st) => this._onStatus(st));

    this.state = GAHandler.State.RUNNING;
    this._updateButtonLabel("停止");
  }

  // ---------------------------------------------------
  // Stop（callApi("Stop")）
  // ---------------------------------------------------
  async stopGA() {
    const res = await callApi("Stop");
    console.log("Stop:", res);

    if (this.stopPolling) {
      this.stopPolling();
      this.stopPolling = null;
    }

    this.state = GAHandler.State.PREVIEW;
    this._updateButtonLabel("反映");
  }

  // ---------------------------------------------------
  // Status（pollApi の callback）
  // ---------------------------------------------------
  _onStatus(status) {
    console.log("Status:", status);

    if (!status.order) return;

    this.latestOrder = status.order;

    const mh = this.selector.markerHandler;

    // markers の順序だけ入れ替える（モデルは触らない）
    mh.markers = status.order.map(i => mh.markers[i]);

    mh.renumberMarkers();
    mh._updatePolyline();
    this.selector.uiManager.updateListUI();
  }

  // ---------------------------------------------------
  // Commit（Optimize は使わない）
  // ---------------------------------------------------
  applyFinalResult() {
    if (!this.latestOrder) return;

    const pts = this.gpxService.getTrkptList();
    const newPts = this.latestOrder.map(i => pts[i]);
    this.gpxService.setTrkptList(newPts);

    const mh = this.selector.markerHandler;
    mh.clearMarkers();
    mh.initMarkers();

    this.state = GAHandler.State.IDLE;
    this._updateButtonLabel("最適化");
  }

  // ---------------------------------------------------
  // Cancel
  // ---------------------------------------------------
  async cancel() {
    if (this.state === GAHandler.State.RUNNING) {
      await this.stopGA();
    }

    if (!this.originalOrder) return;

    const mh = this.selector.markerHandler;
    mh.markers = [...this.originalOrder];

    mh.renumberMarkers();
    mh._updatePolyline();
    this.selector.uiManager.updateListUI();

    this.state = GAHandler.State.IDLE;
    this._updateButtonLabel("最適化");
  }

  // ---------------------------------------------------
  // 入力データ構築
  // ---------------------------------------------------
  _buildInputData() {
    return this.gpxService.getTrkptList().map(p => ({
      lat: p.lat,
      lon: p.lon,
    }));
  }

  // ---------------------------------------------------
  // ボタンラベル更新
  // ---------------------------------------------------
  _updateButtonLabel(label) {
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.gaActionBtnId,
      label
    );
  }
}