export default class AreaHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting", // ← EDITING 相当（円調整）
    PREVIEW: "preview",
  };

  constructor(selector) {
    this.selector = selector;

    this.state = AreaHandler.State.IDLE;

    // Town でいう boundaryLayer / previewLayer / previewTowns 相当
    this.circleLayer = null; // 円（1つだけ）
    this.previewLayer = null; // PREVIEW 用マーカー群
    this.previewTowns = []; // { lat, lng, name }

    // 円編集用
    this.center = null;
    this.radius = 1000;
    this.centerHandle = null;
    this.radiusHandle = null;

    this.centerHandleIcon = L.divIcon({
      className: "",
      html: '<div class="center-handle-ui"></div>',
      iconSize: [20, 20],
    });

    this.radiusHandleIcon = L.divIcon({
      className: "",
      html: '<div class="radius-handle-ui"></div>',
      iconSize: [16, 16],
    });
  }

  init() {
    // 特に非同期初期化は不要
  }

  // ---------------------------------------------------
  // ✅ 共通キャンセルボタンから呼ばれる（Town 焼き直し）
  // ---------------------------------------------------
  onCancel() {
    switch (this.state) {
      case AreaHandler.State.SELECTING:
        // 編集破棄 → IDLE
        this._resetAll();
        this.selector.uiManager.setButtonLabel(
          this.selector.controls.areaActionBtnId,
          "領域追加"
        );
        console.log("🚫 領域追加をキャンセルしました");
        break;

      case AreaHandler.State.PREVIEW:
        // PREVIEW 破棄 → SELECTING に戻す
        this._clearPreview();
        this.state = AreaHandler.State.SELECTING;
        this._createCircleAndHandles();
        this.selector.uiManager.setButtonLabel(
          this.selector.controls.areaActionBtnId,
          "領域選択"
        );
        console.log("🔄 PREVIEW をキャンセル → 再選択モード");
        break;
    }
  }

  // ---------------------------------------------------
  // ✅ キャンセルボタンを有効にするか？（Town 焼き直し）
  // ---------------------------------------------------
  canCancel() {
    return (
      this.state === AreaHandler.State.SELECTING ||
      this.state === AreaHandler.State.PREVIEW
    );
  }

  // ---------------------------------------------------
  // ✅ 領域ボタン（開始 / 確定） — Town の onTownButtonClick 焼き直し
  // ---------------------------------------------------
  onAreaButtonClick() {
    switch (this.state) {
      case AreaHandler.State.IDLE:
        console.log("[AreaHandler] IDLE → SELECTING (mode enter)");

        this.selector.currentMode = this.selector.constructor.Mode.AREA_MODE;

        // ✅ 地図中心を円の中心にする
        this.center = this.selector.map.getCenter();
        // ✅ 円とハンドルを即生成（Town には無いが Area には必要）
        this._createCircleAndHandles();
        console.log("🟦 円を初期表示しました");

        // ✅ 状態遷移
        this.state = AreaHandler.State.SELECTING;

        // ✅ ボタンラベル
        this.selector.uiManager.setButtonLabel(
          this.selector.controls.areaActionBtnId,
          "領域選択"
        );
        this.selector.updateModeUI();
        break;

      case AreaHandler.State.SELECTING:
        // ✅ 正式な確定操作（クリック確定の代替）
        this._confirmSelection();
        break;

      case AreaHandler.State.PREVIEW:
        this._commitTowns();
        console.log("✅ 領域内の place を確定しました");
        break;
    }
  }

  // ---------------------------------------------------
  // ✅ 地図クリック（ショートカット確定） — Town 焼き直し
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.AREA_MODE)
      return;

    const { lat, lng } = e.latlng;

    if (this.state === AreaHandler.State.SELECTING) {
      // 初回クリックで中心が未設定ならここで中心にして円を作る
      if (!this.center) {
        this.center = e.latlng;
        this._createCircleAndHandles();
      }
      await this._previewTowns();
      return;
    }

    if (this.state === AreaHandler.State.PREVIEW) {
      // PREVIEW → SELECTING に戻る（ショートカットキャンセル）
      this._clearPreview();
      this.state = AreaHandler.State.SELECTING;
      this.selector.uiManager.setButtonLabel(
        this.selector.controls.areaActionBtnId,
        "領域選択"
      );
      console.log("🔄 再選択モード：円を調整して地図をクリックしてください");
      return;
    }
  }

  // ---------------------------------------------------
  // ✅ ボタン確定（SELECTING → PREVIEW） — Town の _confirmSelection 焼き直し
  // ---------------------------------------------------
  async _confirmSelection() {
    console.log("✅ ボタン確定：領域を確定します");

    if (!this.center) {
      console.warn("⚠️ 円の中心がありません");
      return;
    }

    await this._previewTowns();
  }

  // ---------------------------------------------------
  // ✅ PREVIEW：円 → Overpass → 仮表示（Town の _previewTowns 焼き直し）
  // ---------------------------------------------------
  async _previewTowns() {
    if (!this.center) {
      console.warn("⚠️ center が未設定のため PREVIEW できません");
      return;
    }

    console.log(
      `🗺️ 領域 PREVIEW: center=${this.center.lat},${this.center.lng} radius=${this.radius}`
    );

    // 既存 PREVIEW を消す
    this._clearPreview();

    // PREVIEW 用レイヤ
    this.previewLayer = L.layerGroup().addTo(this.selector.map);
    this.previewTowns = [];

    const lat = this.center.lat;
    const lon = this.center.lng;
    const r = Math.floor(this.radius);

    const query = `
      [out:json][timeout:25];
      node["place"~"^(neighbourhood|quarter|locality)$"]
        (around:${r},${lat},${lon});
      out body;
    `;

    const url =
      "https://overpass-api.de/api/interpreter?data=" +
      encodeURIComponent(query);

    let json;
    try {
        this.selector.uiManager.setButtonLabel(
          this.selector.controls.areaActionBtnId,
          "(処理中)"
        );

        const res = await fetch(url);

      console.log("[AreaHandler] Overpass status =", res.status);

      // ✅ ここが重要：res.ok をチェック
      if (!res.ok) {
        console.warn("❌ Overpass HTTP エラー:", res.status);

        this.state = AreaHandler.State.SELECTING;
        this.selector.uiManager.setButtonLabel(
          this.selector.controls.areaActionBtnId,
          "領域選択"
        );

        console.log("🔄 PREVIEW 中断 → SELECTING に復帰しました (HTTP エラー)");
        return;
      }

      // ✅ JSON パース（ここで SyntaxError が起きる可能性）
      json = await res.json();
    } catch (e) {
      console.warn("❌ Overpass JSON パースエラー:", e);

      this.state = AreaHandler.State.SELECTING;
      this.selector.uiManager.setButtonLabel(
        this.selector.controls.areaActionBtnId,
        "領域選択"
      );
      this._createCircleAndHandles();

      console.log("🔄 PREVIEW 中断 → SELECTING に復帰しました (JSON エラー)");
      return;
    }

    console.log("[AreaHandler] fetched elements =", json.elements.length);
    json.elements.forEach((el) => {
      if (!el.tags || !el.tags.name) return;

      const t = {
        lat: el.lat,
        lng: el.lon,
        name: el.tags.name,
      };

      this.previewTowns.push(t);

      L.circleMarker([t.lat, t.lng], {
        radius: 4,
        color: "#ff6600",
      }).addTo(this.previewLayer);
    });

    // PREVIEW に入る前にハンドルを消す
    if (this.centerHandle) {
      this.selector.map.removeLayer(this.centerHandle);
      this.centerHandle = null;
    }
    if (this.radiusHandle) {
      this.selector.map.removeLayer(this.radiusHandle);
      this.radiusHandle = null;
    }

    this.state = AreaHandler.State.PREVIEW;
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.areaActionBtnId,
      "領域確定"
    );

    console.log(
      `👁️ 領域内 place を仮表示しました（${this.previewTowns.length} 件）`
    );
  }

  // ---------------------------------------------------
  // ✅ 確定（GPX + Marker 登録）— Town の _commitTowns 焼き直し
  // ---------------------------------------------------
  _commitTowns() {
    this.previewTowns.forEach((t) => {
      const trkpt = {
        lat: t.lat,
        lon: t.lng,
        name: t.name, // desc / extensions は不要
      };

      const added = this.selector.gpxService.addTrkpt(trkpt);
      this.selector.markerHandler.addPoint(added);
    });

    console.log(`✅ GPX + Marker 登録完了: ${this.previewTowns.length} 件`);

    this._resetAll();
  }

  // ---------------------------------------------------
  // ✅ PREVIEW のクリア — Town の _clearPreview 焼き直し
  // ---------------------------------------------------
  _clearPreview() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
    this.previewTowns = [];
  }

  // ---------------------------------------------------
  // ✅ 全リセット（DEFAULT に戻す）— Town の _resetAll 焼き直し
  // ---------------------------------------------------
  _resetAll() {
    this._clearPreview();

    // 円とハンドルを消す
    if (this.circleLayer) {
      this.selector.map.removeLayer(this.circleLayer);
      this.circleLayer = null;
    }
    if (this.centerHandle) {
      this.selector.map.removeLayer(this.centerHandle);
      this.centerHandle = null;
    }
    if (this.radiusHandle) {
      this.selector.map.removeLayer(this.radiusHandle);
      this.radiusHandle = null;
    }

    this.center = null;
    this.radius = 1000;

    this.state = AreaHandler.State.IDLE;
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this.selector.updateModeUI();

    this.selector.uiManager.setButtonLabel(
      this.selector.controls.areaActionBtnId,
      "領域追加"
    );
  }

  // ---------------------------------------------------
  // ✅ 円 + ハンドル生成（Town にはないが責務はここに集中）
  // ---------------------------------------------------
  _createCircleAndHandles() {
    if (!this.center) return;

    // ✅ 円の更新 or 初期生成
    if (!this.circleLayer) {
      this.circleLayer = L.circle(this.center, {
        radius: this.radius,
        color: "#0078ff",
        weight: 2,
        fillColor: "#0078ff",
        fillOpacity: 0.15,
      }).addTo(this.selector.map);
    } else {
      this.circleLayer.setLatLng(this.center);
      this.circleLayer.setRadius(this.radius);
    }

    // ✅ 中心ハンドルの更新 or 初期生成
    if (!this.centerHandle) {
      this.centerHandle = L.marker(this.center, {
        draggable: true,
        icon: this.centerHandleIcon,
      }).addTo(this.selector.map);

      this.centerHandle.setZIndexOffset(9999);

      this.centerHandle.on("drag", (e) => {
        this.center = e.target.getLatLng();
        this._createCircleAndHandles(); // ✅ 再描画
      });
    } else {
      this.centerHandle.setLatLng(this.center);
    }

    // ✅ 半径ハンドルの位置を計算
    const pos = this._computeHandleLatLng(this.center, this.radius);

    if (!this.radiusHandle) {
      this.radiusHandle = L.marker(pos, {
        draggable: true,
        icon: this.radiusHandleIcon,
      }).addTo(this.selector.map);

      this.radiusHandle.setZIndexOffset(9998);

      this.radiusHandle.on("drag", (e) => {
        this.radius = e.target.getLatLng().distanceTo(this.center);
        this._createCircleAndHandles(); // ✅ 再描画
      });
    } else {
      this.radiusHandle.setLatLng(pos);
    }
  }

  _computeHandleLatLng(center, radius) {
    const earth = 6378137;
    const latRad = (center.lat * Math.PI) / 180;
    const deltaLon = (radius / (earth * Math.cos(latRad))) * (180 / Math.PI);
    return L.latLng(center.lat, center.lng + deltaLon);
  }
}
