export default class TownHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",   // ← EDITING 相当
    PREVIEW: "preview",
  };

  constructor(selector) {
    this.selector = selector;

    this.state = TownHandler.State.IDLE;

    this.boundaryLayer = null;
    this.previewLayer = null;
    this.previewTowns = [];

    this.muniData = null;
  }

  async init() {
    const res = await fetch("./municipalities.json");
    this.muniData = await res.json();
  }

  resolveAdmin(muniCd5) {
    return this.muniData.municipalities.find((m) => m.muniCd5 === muniCd5);
  }

  // ---------------------------------------------------
  // ✅ 共通キャンセルボタンから呼ばれる
  // ---------------------------------------------------
  onCancel() {
    switch (this.state) {
      case TownHandler.State.SELECTING:
        // 編集破棄 → IDLE
        this._resetAll();
        console.log("🚫 町字追加をキャンセルしました");
        break;

      case TownHandler.State.PREVIEW:
        // PREVIEW 破棄 → SELECTING に戻す
        this._clearPreview();
        this.state = TownHandler.State.SELECTING;
        this.selector.uiManager.setButtonLabel(
          this.selector.controls.townActionBtnId,
          "町字確定"
        );
        console.log("🔄 PREVIEW をキャンセル → 再選択モード");
        break;
    }
  }

  // ---------------------------------------------------
  // ✅ キャンセルボタンを有効にするか？
  // ---------------------------------------------------
  canCancel() {
    return (
      this.state === TownHandler.State.SELECTING ||
      this.state === TownHandler.State.PREVIEW
    );
  }

  // ---------------------------------------------------
  // ✅ 町字追加ボタン（開始 / 確定）
  // ---------------------------------------------------
  onTownButtonClick() {
    switch (this.state) {
      case TownHandler.State.IDLE:
        this.selector.currentMode = this.selector.constructor.Mode.TOWN_MODE;
        this.selector.updateModeUI();

        this.state = TownHandler.State.SELECTING;
        this.selector.uiManager.setButtonLabel(
          this.selector.controls.townActionBtnId,
          "町字確定"
        );
        console.log("🗺️ 自治体選択モード：地図をクリックしてください");
        break;

      case TownHandler.State.SELECTING:
        // ✅ 正式な確定操作（クリック確定の代替）
        this._confirmSelection();
        break;

      case TownHandler.State.PREVIEW:
        this._commitTowns();
        console.log("✅ 町字を確定しました");
        break;
    }
  }

  // ---------------------------------------------------
  // ✅ 地図クリック（ショートカット確定）
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.TOWN_MODE)
      return;

    const { lat, lng } = e.latlng;

    if (this.state === TownHandler.State.SELECTING) {
      await this._previewTowns(lat, lng);
      return;
    }

    if (this.state === TownHandler.State.PREVIEW) {
      // PREVIEW → SELECTING に戻る（ショートカットキャンセル）
      this._clearPreview();
      this.state = TownHandler.State.SELECTING;
      this.selector.uiManager.setButtonLabel(
        this.selector.controls.townActionBtnId,
        "町字確定"
      );
      console.log("🔄 再選択モード：地図をクリックしてください");
      return;
    }
  }

  // ---------------------------------------------------
  // ✅ ボタン確定（SELECTING → PREVIEW）
  // ---------------------------------------------------
  async _confirmSelection() {
    console.log("✅ ボタン確定：自治体を確定します");
    // 直前のクリック位置を保持しておく必要があるなら selector に保存しておく
    if (!this.selector.lastClickLatLng) {
      console.warn("⚠️ クリック位置がありません");
      return;
    }
    const { lat, lng } = this.selector.lastClickLatLng;
    await this._previewTowns(lat, lng);
  }

  // ---------------------------------------------------
  // ✅ PREVIEW：自治体選択 → 町字取得 → 仮表示
  // ---------------------------------------------------
  async _previewTowns(lat, lng) {
    console.log(`🗺️ 自治体選択クリック: ${lat}, ${lng}`);

    // クリック位置を保存（ボタン確定用）
    this.selector.lastClickLatLng = { lat, lng };

    const gsi = await this.fetchGsi(lat, lng);
    if (!gsi) return;

    const admin = this.resolveAdmin(gsi.muniCd);
    if (!admin) {
      console.warn("❌ municipalities.json に自治体が見つかりません");
      return;
    }

    const { name: muniName, prefecture: prefName, muniCd6 } = admin;

    console.log(`✅ 自治体: ${prefName} ${muniName}`);

    await this.fetchBoundary(gsi.muniCd);

    const towns = await this.fetchTowns(prefName, muniName);
    if (!towns.length) {
      console.warn("❌ 町字が取得できませんでした");
      return;
    }

    this.previewLayer = L.layerGroup().addTo(this.selector.map);
    towns.forEach((t) => {
      L.circleMarker([t.lat, t.lng], { radius: 4, color: "#ff6600" }).addTo(
        this.previewLayer
      );
    });

    this.previewTowns = towns;
    this.previewAdmin = { muniName, prefName, muniCd6 };

    this.state = TownHandler.State.PREVIEW;
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.townActionBtnId,
      "町字確定"
    );

    console.log(`👁️ 町字を仮表示しました（${towns.length} 件）`);
  }

  // ---------------------------------------------------
  // ✅ 確定（GPX + Marker 登録）
  // ---------------------------------------------------
  _commitTowns() {
    const { muniName, prefName, muniCd6 } = this.previewAdmin;

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

      const added = this.selector.gpxService.addTrkpt(trkpt);
      this.selector.markerHandler.addPoint(added);
    });

    console.log(`✅ GPX + Marker 登録完了: ${this.previewTowns.length} 件`);

    this._resetAll();
  }

  // ---------------------------------------------------
  // ✅ PREVIEW のクリア
  // ---------------------------------------------------
  _clearPreview() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
    this.previewTowns = [];
  }

  // ---------------------------------------------------
  // ✅ 全リセット（DEFAULT に戻す）
  // ---------------------------------------------------
  _resetAll() {
    this._clearPreview();

    if (this.boundaryLayer) {
      this.selector.map.removeLayer(this.boundaryLayer);
      this.boundaryLayer = null;
    }

    this.state = TownHandler.State.IDLE;
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this.selector.updateModeUI();

    this.selector.uiManager.setButtonLabel(
      this.selector.controls.townActionBtnId,
      "町字追加"
    );
  }

  // ---------------------------------------------------
  // ✅ API 群
  // ---------------------------------------------------
  async fetchGsi(lat, lng) {
    const url = `https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=${lat}&lon=${lng}`;
    try {
      const res = await fetch(url).then((r) => r.json());
      return { muniCd: res.results.muniCd };
    } catch {
      return null;
    }
  }

  async fetchBoundary(muniCd5) {
    const url = `https://shikuchoson-boundaries.sankichi.app/${muniCd5}.geojson`;
    try {
      const geojson = await fetch(url).then((r) => r.json());
      this.drawBoundary(geojson);
    } catch {}
  }

  drawBoundary(geojson) {
    if (this.boundaryLayer) this.selector.map.removeLayer(this.boundaryLayer);

    this.boundaryLayer = L.geoJSON(geojson, {
      style: { color: "#3388ff", weight: 2 },
    }).addTo(this.selector.map);

    this.selector.map.fitBounds(this.boundaryLayer.getBounds());
  }

  async fetchTowns(prefName, muniName) {
    const url = `https://geolonia.github.io/japanese-addresses/api/ja/${prefName}/${muniName}.json`;
    try {
      return await fetch(url).then((r) => r.json());
    } catch {
      return [];
    }
  }
}