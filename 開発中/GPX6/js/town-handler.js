import { fetchMuniInfo, fetchBoundary, fetchTowns } from "./api-utils.js";

function drawBoundary(map, geojson) {
  return L.geoJSON(geojson, {
    style: { color: "#3388ff", weight: 2 },
  }).addTo(map);
}

export default class TownHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle: { label: "町字追加", canCancel: false },
    selecting: { label: "町字確定", canCancel: true },
    preview: { label: "登録", canCancel: true },
  };

  constructor(selector) {
    this.selector = selector;
    this.state = TownHandler.State.IDLE;

    this.tempData = null; // lat/lng
    this.previewLayer = null; // 町字プレビュー
    this.boundaryLayer = null; // 自治体境界
    this.previewTowns = []; // 町字一覧
    this.previewAdmin = null; // 自治体情報
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  init() {}

  // ---------------------------------------------------
  // ボタン押下
  // ---------------------------------------------------
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

  // ---------------------------------------------------
  // キャンセル（PREVIEW → SELECTING に戻す）
  // ---------------------------------------------------
  handleCancel() {
    if (this.state === TownHandler.State.PREVIEW) {
      // PREVIEW → SELECTING（元コードと同じ挙動）
      this._clearPreviewOnly();
      this.changeState(TownHandler.State.SELECTING);
      return;
    }

    // IDLE / SELECTING はテンプレ通り
    this.changeState(TownHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // Map click
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.TOWN_MODE)
      return;

    if (this.state === TownHandler.State.SELECTING) {
      this.tempData = { lat: e.latlng.lat, lng: e.latlng.lng };
      await this._loadPreviewData();
      this.changeState(TownHandler.State.PREVIEW);
    } else if (this.state === TownHandler.State.PREVIEW) {
      this.handleCancel();
    }
  }

  // ---------------------------------------------------
  // 状態遷移
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    switch (newState) {
      case TownHandler.State.IDLE:
        this._clear();
        break;

      case TownHandler.State.SELECTING:
        this._prepareSelecting();
        break;

      case TownHandler.State.PREVIEW:
        this._preparePreview();
        break;
    }

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...TownHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // 内部ロジック
  // ---------------------------------------------------

  // IDLE → SELECTING
  _start() {
    this.selector.setMode(this.selector.constructor.Mode.TOWN_MODE);
    this.changeState(TownHandler.State.SELECTING);
  }

  // SELECTING → PREVIEW（ボタン確定）
  async _preview() {
    if (!this.tempData) return;
    await this._loadPreviewData();
    this.changeState(TownHandler.State.PREVIEW);
  }

  // PREVIEW → IDLE（登録）
  _confirm() {
    const { name: muniName, prefecture: prefName, muniCd6 } = this.previewAdmin;

    this.previewTowns.forEach((t) => {
      const trkpt = {
        lat: t.lat,
        lon: t.lng,
        name: t.town,
        desc: `${prefName}${muniName}${t.town}`,
        extensions: {
          quarter: t.town,
          muni: muniName,
          province: prefName,
          muniCd: muniCd6,
          country: "日本",
          country_code: "jp",
        },
      };

      const added = this.selector.gpxService.appendTrkpt(trkpt);
      this.selector.addPoint(added);
    });

    console.log(`✅ GPX + Marker 登録完了: ${this.previewTowns.length} 件`);

    this.changeState(TownHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // 内部処理
  // ---------------------------------------------------

  async _loadPreviewData() {
    const { lat, lng } = this.tempData;

    // 自治体
    const admin = await fetchMuniInfo(lat, lng);
    if (!admin) return;
    this.previewAdmin = admin;

    // 境界
    const geojson = await fetchBoundary(admin);
    if (geojson) {
      if (this.boundaryLayer) {
        this.selector.map.removeLayer(this.boundaryLayer);
      }
      this.boundaryLayer = drawBoundary(this.selector.map, geojson);
      this.selector.map.fitBounds(this.boundaryLayer.getBounds());
    }

    // 町字
    const towns = await fetchTowns(admin);
    this.previewTowns = towns;

    // プレビュー描画
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
    }
    this.previewLayer = L.layerGroup().addTo(this.selector.map);

    towns.forEach((t) => {
      L.circleMarker([t.lat, t.lng], {
        radius: 4,
        color: "#ff6600",
      }).addTo(this.previewLayer);
    });

    console.log(`👁️ 町字プレビュー: ${towns.length} 件`);
  }

  _clear() {
    this.tempData = null;

    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }

    if (this.boundaryLayer) {
      this.selector.map.removeLayer(this.boundaryLayer);
      this.boundaryLayer = null;
    }

    this.previewTowns = [];
    this.previewAdmin = null;
  }

  _clearPreviewOnly() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
  }

  _prepareSelecting() {
    this.tempData = null;
  }

  _preparePreview() {
    // previewLayer は _loadPreviewData 内で構築済み
  }
}
