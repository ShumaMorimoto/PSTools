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
    this.latestIndices = null; // インデックスとして扱う
    this.originalMarkers = null; // マーカー配列のコピー
    this.originalTrkpts = null; // モデルデータのコピー
  }

  // ---------------------------------------------------
  // GA ボタンクリックハンドラ: 状態に応じて動作を切り替え
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
  // 地図クリックハンドラ: 状態に応じて動作を切り替え
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
        // デフォルトの地図クリック動作（selector側で処理される想定）
        break;
    }
  }

  // ---------------------------------------------------
  // Start GA: 最適化開始
  // ---------------------------------------------------
  async startGA() {
    // オリジナルデータを保存
    this.originalMarkers = [...this.selector.markerHandler.markers];
    this.originalTrkpts = [...this.gpxService.getTrkpts()];

    const input = this._buildInputData();
    const res = await callApi("Start", input);
    console.log("Start:", res);

    // ポーリング開始
    if (this.stopPolling) this.stopPolling();
    this.stopPolling = pollApi("Status", 1000, (st) => this._onStatus(st));

    console.log("[GAHandler] IDLE → SELECTING");
    this.selector.currentMode = this.selector.constructor.Mode.GA_MODE;
    this.state = GAHandler.State.RUNNING;
    this._updateButtonLabel("停止");
    console.log("🗺️ 最適化を中断する場合はボタンをクリックしてください");
  }

  // ---------------------------------------------------
  // Stop GA: 最適化中断（プレビューへ移行）
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
  // Status Callback: ポーリングで定期的に呼ばれる
  // ---------------------------------------------------
  _onStatus(status) {
    // 結果が無効ならスキップ
    if (!status?.Result) return;

    console.log("Status: ", status.Result);

    const routeIndices = status.Result.Route;
    if (!routeIndices) return;

    // 最新インデックス更新
    this.latestIndices = routeIndices;

    // UIをプレビュー更新（originalMarkersをベースに並べ替え）
    const mh = this.selector.markerHandler;
    mh.markers = this.latestIndices.map((i) => this.originalMarkers[i]);
    mh.renumberMarkers();
    mh._updatePolyline();
    this.selector.uiManager.updateListUI();
  }

  // ---------------------------------------------------
  // Apply Final Result: プレビューを確定（モデルに反映）
  // ---------------------------------------------------
  applyFinalResult() {
    if (!this.latestIndices) {
      console.warn("No latest indices to apply.");
      return;
    }

    // モデル（trkpts）を並べ替え
    const newTrkpts = this.latestIndices.map((i) => this.originalTrkpts[i]);
    this.gpxService.setTrkpts(newTrkpts);

    // UIはすでにプレビュー状態なので、renumberだけ（二重適用回避）
    const mh = this.selector.markerHandler;
    mh.renumberMarkers(); // 必要なら
    mh._updatePolyline(); // 必要なら

    // リンクチェック
    console.log("=== Link Check After Apply ===");
    const finalTrkpts = this.gpxService.getTrkpts();
    mh.markers.forEach((entry, idx) => {
      const markerPos = entry.m.getLatLng(); // 仮定: entry.m がLeafletマーカー
      const pointPos = { lat: entry.point.lat, lon: entry.point.lon }; // 仮定: entry.point
      const modelPos = { lat: finalTrkpts[idx].lat, lon: finalTrkpts[idx].lon };
      console.log(`Index ${idx}:`, {
        markerLatLng: markerPos,
        pointLatLon: pointPos,
        modelLatLon: modelPos,
        pointMatchesModel: entry.point === finalTrkpts[idx],
        markerMatchesPoint:
          markerPos.lat === entry.point.lat &&
          markerPos.lng === entry.point.lon,
      });
    });
    console.log("=== End Link Check ===");

    this._resetAll();
  }

  // ---------------------------------------------------
  // Cancel: プレビュー/実行中をキャンセルしてIDLEに戻す
  // ---------------------------------------------------
  async cancel() {
    // RUNNING時はまずstopGA
    if (this.state === GAHandler.State.RUNNING) {
      await this.stopGA();
    }

    // オリジナルデータでUI/モデルを復元
    if (this.originalMarkers && this.originalTrkpts) {
      const mh = this.selector.markerHandler;
      mh.markers = [...this.originalMarkers];
      this.gpxService.setTrkpts([...this.originalTrkpts]);

      mh.renumberMarkers();
      mh._updatePolyline();
      this.selector.uiManager.updateListUI();
    }

    this._resetAll();
  }

  // ---------------------------------------------------
  // 入力データ構築
  // ---------------------------------------------------
  _buildInputData() {
    return this.gpxService.getTrkpts().map((p) => ({
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

  // ---------------------------------------------------
  // MODE同期: 状態変更時にselector.MODEを更新
  // ---------------------------------------------------
  _resetAll() {
    // クリーンアップ
    this.latestIndices = null;
    this.originalMarkers = null;
    this.originalTrkpts = null;

    this.state = GAHandler.State.IDLE;
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this._updateButtonLabel("最適化");
    this.selector.updateModeUI();
  }
}
