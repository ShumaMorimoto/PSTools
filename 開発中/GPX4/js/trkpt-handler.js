// js/trkpt-handler.js (新規ハンドラクラス)

import { callApi } from "/runapp/lib/js/api.js";

export default class TrkptHandler {
  static State = {
    IDLE: "idle",
    PROCESSING: "processing",
  };

  constructor(selector) {
    this.selector = selector;
    this.state = TrkptHandler.State.IDLE;
  }

  init() {
    // 初期化不要
  }

  // ---------------------------------------------------
  // ボタンクリック（処理開始）
  // ---------------------------------------------------
  onProcessButtonClick() {
    if (this.state === TrkptHandler.State.IDLE) {
      this._processTrkpts();
    }
  }

  // ---------------------------------------------------
  // TRKPT処理（PowerShell経由）
  // ---------------------------------------------------
  async _processTrkpts() {
    if (this.state !== TrkptHandler.State.IDLE) return;

    this.state = TrkptHandler.State.PROCESSING;
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.processTrkptsBtnId,
      "(処理中)"
    );

    // 現在のTRKPT一覧を取得（JSON用配列）
    const trkpts = this.selector.gpxService.getTrkptList().map((pt) => ({
      lat: pt.lat,
      lon: pt.lon,
      name: pt.name,
      // 他のフィールドが必要なら追加
    }));

    if (trkpts.length === 0) {
      console.warn("⚠️ TRKPTがありません");
      this._reset();
      return;
    }

    console.log(`🗺️ TRKPT処理: ${trkpts.length} 件`);

    try {
      // PowerShell経由で処理（processTrkptsプロセス）
      const processed = await callApi("Optimize", trkpts);
     

      this.selector.markerHandler.clearMarkers()

      // 処理結果をGPXに登録
      processed.forEach((t) => {
        const trkpt = {
          lat: t.lat,
          lon: t.lng || t.lon, // lng or lon
          name: t.name,
          // 他のフィールド
        };
        const added = this.selector.gpxService.addTrkpt(trkpt);
        this.selector.markerHandler.addPoint(added);
      });

      console.log(`✅ TRKPT処理&登録完了: ${processed.length} 件`);
    } catch (e) {
      console.warn("❌ TRKPT処理エラー:", e);
    }

    this._reset();
  }

  // ---------------------------------------------------
  // リセット
  // ---------------------------------------------------
  _reset() {
    this.state = TrkptHandler.State.IDLE;
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.processTrkptsBtnId,
      "PS処理"
    );
  }
}
