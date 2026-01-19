import { geoService } from "./components/geo-service.js"; // インスタンスをインポート

function drawBoundary(map, geojson) {
  return L.geoJSON(geojson, {
    style: { color: "#3388ff", weight: 2 },
  }).addTo(map);
}

export default class TownHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PROCESSING: "processing", // 💡 追加
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle: { label: "町字追加", canCancel: false },
    selecting: { label: "町字確定", canCancel: true },
    processing: { label: "処理中...", canCancel: false, isBusy: true }, // 💡 追加（canCancel: false）
    preview: { label: "登録", canCancel: true },
  };

  constructor(selector) {
    this.selector = selector;
    this.state = TownHandler.State.IDLE;

    this.tempPoint = null; // 統一IF形式のPointオブジェクトを保持
    this.previewLayer = null;
    this.boundaryLayer = null;
    this.previewTowns = []; // geoServiceから返るPoint配列
  }

  // ... (init, onActionButtonClick, handleCancel は変更なし) ...
  init() {}

  onActionButtonClick() {
    switch (this.state) {
      case TownHandler.State.IDLE:
        this._start();
        break;
      case TownHandler.State.SELECTING:
        this._preview();
        break;
      case TownHandler.State.PREVIEW:
        this._confirm();
        break;
    }
  }

  handleCancel() {
    if (this.state === TownHandler.State.PREVIEW) {
      this._clearPreviewOnly();
      this.changeState(TownHandler.State.SELECTING);
      return;
    }
    this.changeState(TownHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // Map click
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.TOWN_MODE)
      return;

    // 💡 SELECTING 状態の時のみクリックを受け付ける
    if (this.state === TownHandler.State.SELECTING) {
      this.tempPoint = { lat: e.latlng.lat, lon: e.latlng.lng };

      // 💡 状態を PROCESSING に変えてからロード開始
      this.changeState(TownHandler.State.PROCESSING);

      try {
        await this._loadPreviewData();
        this.changeState(TownHandler.State.PREVIEW);
      } catch (err) {
        console.error("ロード失敗", err);
        this.changeState(TownHandler.State.SELECTING); // 失敗時は戻す
      }
    } else if (this.state === TownHandler.State.PREVIEW) {
      this.handleCancel();
    }
  }

  // ---------------------------------------------------
  // 内部ロジック
  // ---------------------------------------------------

  // PREVIEW → IDLE（登録）
  _confirm() {
    if (!this.previewTowns.length) return;

    // geoServiceから返ってきたPoint配列(this.previewTowns)を
    // そのままセレクターの addPoints に渡せる（IFが統一されているため）
    // もし既存の extensions 構造を厳格に維持したい場合は map で調整
    const pts = this.previewTowns.map((pt) => ({
      lat: pt.lat,
      lon: pt.lon,
      name: pt.name,
      desc: pt.desc,
      extensions: {
        quarter: pt.name,
        muni: pt.extensions.municipality,
        province: pt.extensions.prefecture,
        muniCd: pt.extensions.muniCd6,
        country: "日本",
        country_code: "jp",
      },
    }));

    this.selector.addPoints(pts);
    this.selector.reorderMarkers();

    console.log(`✅ 登録完了: ${pts.length} 件`);
    this.changeState(TownHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  async _loadPreviewData() {
    // 1. 自治体情報の解決
    // 引数の this.tempPoint 自体に extensions と desc が生える
    await geoService.resolve(this.tempPoint);

    if (!this.tempPoint.extensions) return;

    // 2. 境界線の取得と描画 (fetchBoundaryも補完された情報を使う)
    const geojson = await geoService.fetchBoundary(this.tempPoint);
    if (geojson) {
      if (this.boundaryLayer) this.selector.map.removeLayer(this.boundaryLayer);
      this.boundaryLayer = drawBoundary(this.selector.map, geojson);
      this.selector.map.fitBounds(this.boundaryLayer.getBounds());
    }

    // 3. 自治体内全町字の取得
    // すでに prefecture, municipality が注入されているのでそのまま渡せる
    this.previewTowns = await geoService.fetchCityTowns(this.tempPoint);

    // 4. プレビュー描画
    if (this.previewLayer) this.selector.map.removeLayer(this.previewLayer);
    this.previewLayer = L.layerGroup().addTo(this.selector.map);

    this.previewTowns.forEach((t) => {
      L.circleMarker([t.lat, t.lon], {
        radius: 4,
        color: "#ff6600",
      }).addTo(this.previewLayer);
    });

    console.log(
      `👁️ 町字プレビュー: ${this.previewTowns.length} 件 (${this.tempPoint.desc})`
    );
  }

  changeState(newState) {
    this.state = newState;
    switch (newState) {
      case TownHandler.State.IDLE:
        this._clear();
        break;
      case TownHandler.State.SELECTING:
        this._prepareSelecting();
        break;
      case TownHandler.State.PROCESSING:
        /* ロック中 */ break; // 💡 追加
      case TownHandler.State.PREVIEW:
        this._preparePreview();
        break;
    }
    this.selector.onHandlerStateChanged({
      state: newState,
      ...TownHandler.StateInfo[newState],
    });
  }

  _start() {
    this.selector.setMode(this.selector.constructor.Mode.TOWN_MODE);
    this.changeState(TownHandler.State.SELECTING);
  }

  async _preview() {
    if (!this.tempPoint) return;
    this.changeState(TownHandler.State.PROCESSING);
    try {
      await this._loadPreviewData();
      this.changeState(TownHandler.State.PREVIEW);
    } catch (e) {
      this.changeState(TownHandler.State.SELECTING);
    }
  }

  _clear() {
    this.tempPoint = null;
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
    if (this.boundaryLayer) {
      this.selector.map.removeLayer(this.boundaryLayer);
      this.boundaryLayer = null;
    }
    this.previewTowns = [];
  }

  _clearPreviewOnly() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
  }

  _prepareSelecting() {
    this.tempPoint = null;
  }
  _preparePreview() {}
}
