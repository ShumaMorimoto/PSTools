import {fetchMuniInfo,fetchBoundary, fetchTowns} from "./api-utils.js";

/**
 * GeoJSONを地図に描画
 */
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

  constructor(selector) {
    this.selector = selector;
    this.state = TownHandler.State.IDLE;

    this.boundaryLayer = null;
    this.previewLayer = null;
    this.previewTowns = [];
    this.previewAdmin = null;
  }

  async init() {
    // municipalities.json のロードは api-utils 内部で自動キャッシュされる
  }

  // ---------------------------------------------------
  // キャンセル処理
  // ---------------------------------------------------
  onCancel() {
    switch (this.state) {
      case TownHandler.State.SELECTING:
        this._resetAll();
        console.log("🚫 町字追加をキャンセルしました");
        break;

      case TownHandler.State.PREVIEW:
        this._clearPreview();
        this.state = TownHandler.State.SELECTING;
        this._updateButtonLabel("町字確定");
        console.log("🔄 PREVIEW をキャンセル → 再選択モード");
        break;
    }
  }

  canCancel() {
    return this.state !== TownHandler.State.IDLE;
  }

  // ---------------------------------------------------
  // ボタンクリック
  // ---------------------------------------------------
  onTownButtonClick() {
    switch (this.state) {
      case TownHandler.State.IDLE:
        this._enterSelectingMode();
        break;

      case TownHandler.State.SELECTING:
        this._confirmSelection();
        break;

      case TownHandler.State.PREVIEW:
        this._commitTowns();
        break;
    }
  }

  // ---------------------------------------------------
  // 地図クリック
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.TOWN_MODE)
      return;

    if (this.state === TownHandler.State.SELECTING) {
      await this._previewTowns(e.latlng.lat, e.latlng.lng);
    } else if (this.state === TownHandler.State.PREVIEW) {
      this._clearPreview();
      this.state = TownHandler.State.SELECTING;
      this._updateButtonLabel("町字確定");
      console.log("🔄 再選択モード：地図をクリックしてください");
    }
  }

  // ---------------------------------------------------
  // SELECTING モードへ
  // ---------------------------------------------------
  _enterSelectingMode() {
    console.log("[TownHandler] IDLE → SELECTING");
    this.selector.currentMode = this.selector.constructor.Mode.TOWN_MODE;
    this.selector.updateModeUI();
    this.state = TownHandler.State.SELECTING;
    this._updateButtonLabel("町字確定");
    console.log("🗺️ 自治体選択モード：地図をクリックしてください");
  }

  // ---------------------------------------------------
  // ボタン確定 → PREVIEW
  // ---------------------------------------------------
  async _confirmSelection() {
    console.log("✅ ボタン確定：自治体を確定します");
    if (!this.selector.lastClickLatLng) {
      console.warn("⚠️ クリック位置がありません");
      return;
    }
    const { lat, lng } = this.selector.lastClickLatLng;
    await this._previewTowns(lat, lng);
  }

  // ---------------------------------------------------
  // PREVIEW：自治体取得 → 境界 → 町字
  // ---------------------------------------------------
  async _previewTowns(lat, lng) {
    console.log(`🗺️ 自治体選択クリック: ${lat}, ${lng}`);

    this.selector.lastClickLatLng = { lat, lng };

    // ★ ここが新しい：muniInfo を一発取得
    const admin = await fetchMuniInfo(lat, lng);
    if (!admin) {
      console.warn("❌ 自治体情報が取得できません");
      return;
    }

    console.log(`✅ 自治体: ${admin.prefecture} ${admin.name}`);

    // 境界取得
    const geojson = await fetchBoundary(admin);
    if (!geojson) {
      console.warn("❌ 境界GeoJSON取得エラー");
      return;
    }

    if (this.boundaryLayer) {
      this.selector.map.removeLayer(this.boundaryLayer);
    }
    this.boundaryLayer = drawBoundary(this.selector.map, geojson);
    this.selector.map.fitBounds(this.boundaryLayer.getBounds());

    // 町字取得
    const towns = await fetchTowns(admin);
    if (!towns.length) {
      console.warn("❌ 町字が取得できませんでした");
      return;
    }

    this._clearPreview();
    this.previewLayer = L.layerGroup().addTo(this.selector.map);

    towns.forEach((t) => {
      L.circleMarker([t.lat, t.lng], {
        radius: 4,
        color: "#ff6600",
      }).addTo(this.previewLayer);
    });

    this.previewTowns = towns;
    this.previewAdmin = admin;

    this.state = TownHandler.State.PREVIEW;
    this._updateButtonLabel("町字確定");

    console.log(`👁️ 町字を仮表示しました（${towns.length} 件）`);
  }

  // ---------------------------------------------------
  // PREVIEW → IDLE：GPX + Marker 登録
  // ---------------------------------------------------
  _commitTowns() {
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
      this.selector.markerHandler.addPoint(added);
    });

    console.log(`✅ GPX + Marker 登録完了: ${this.previewTowns.length} 件`);
    this._resetAll();
  }

  _updateButtonLabel(label) {
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.townActionBtnId,
      label
    );
  }

  _clearPreview() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
    this.previewTowns = [];
    this.previewAdmin = null;
  }

  _resetAll() {
    this._clearPreview();
    if (this.boundaryLayer) {
      this.selector.map.removeLayer(this.boundaryLayer);
      this.boundaryLayer = null;
    }
    this.selector.lastClickLatLng = null;
    this.state = TownHandler.State.IDLE;
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this._updateButtonLabel("町字追加");
    this.selector.updateModeUI();
  }
}