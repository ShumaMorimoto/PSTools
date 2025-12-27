
import { fetchOverpassPlaces } from "./api-utils.js";

export default class AreaHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting", // 円調整モード
    PREVIEW: "preview", // プレビューモード
  };

  constructor(selector) {
    this.selector = selector;
    this.state = AreaHandler.State.IDLE;

    // レイヤーとデータ
    this.circleLayer = null;
    this.previewLayer = null;
    this.previewTowns = [];

    // 円編集用
    this.center = null;
    this.radius = 500;
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
    // 非同期初期化不要
  }

  // ---------------------------------------------------
  // キャンセル処理（共通キャンセルボタンから呼ばれる）
  // ---------------------------------------------------
  onCancel() {
    switch (this.state) {
      case AreaHandler.State.SELECTING:
        this._resetAll();
        this._updateButtonLabel("領域追加");
        console.log("🚫 領域追加をキャンセルしました");
        break;

      case AreaHandler.State.PREVIEW:
        this._clearPreview();
        this._createCircleAndHandles();
        this.state = AreaHandler.State.SELECTING;
        this._updateButtonLabel("領域選択");
        console.log("🔄 PREVIEW をキャンセル → 再選択モード");
        break;
    }
  }

  // ---------------------------------------------------
  // キャンセル可能か？
  // ---------------------------------------------------
  canCancel() {
    return this.state !== AreaHandler.State.IDLE;
  }

  // ---------------------------------------------------
  // 領域ボタンクリック（開始 / 確定）
  // ---------------------------------------------------
  onAreaButtonClick() {
    switch (this.state) {
      case AreaHandler.State.IDLE:
        this._enterSelectingMode();
        break;

      case AreaHandler.State.SELECTING:
        this._previewTowns();
        break;

      case AreaHandler.State.PREVIEW:
        this._commitTowns();
        break;
    }
  }

  // ---------------------------------------------------
  // 地図クリック（ショートカット確定 / キャンセル）
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.AREA_MODE)
      return;

    if (this.state === AreaHandler.State.SELECTING) {
      if (!this.center) {
        this.center = e.latlng;
        this._createCircleAndHandles();
      }
      await this._previewTowns();
    }
//     else if (this.state === AreaHandler.State.PREVIEW) {
//      this._clearPreview();
//      this._createCircleAndHandles();
//      this.state = AreaHandler.State.SELECTING;
//      this._updateButtonLabel("領域選択");
//      console.log("🔄 再選択モード：円を調整して地図をクリックしてください");
//    }
  }

  // ---------------------------------------------------
  // SELECTINGモードに入る
  // ---------------------------------------------------
  _enterSelectingMode() {
    console.log("[AreaHandler] IDLE → SELECTING");
    this.selector.currentMode = this.selector.constructor.Mode.AREA_MODE;
    this.center = this.selector.map.getCenter();
    this._createCircleAndHandles();
    this.state = AreaHandler.State.SELECTING;
    this._updateButtonLabel("領域選択");
    this.selector.updateModeUI();
    console.log("🟦 円を初期表示しました");
  }

  // ---------------------------------------------------
  // PREVIEW：Overpassで町字取得 → 仮表示
  // ---------------------------------------------------
  async _previewTowns() {
    if (!this.center) {
      console.warn("⚠️ center が未設定のため PREVIEW できません");
      return;
    }

    console.log(
      `🗺️ 領域 PREVIEW: center=${this.center.lat},${this.center.lng} radius=${this.radius}`
    );

    this._clearPreview();
    this.previewLayer = L.layerGroup().addTo(this.selector.map);
    this.previewTowns = [];

    this._updateButtonLabel("(処理中)");

    try {
      this.previewTowns = await fetchOverpassPlaces(
        this.center.lat,
        this.center.lng,
        this.radius
      );

      this.previewTowns.forEach((t) => {
        L.circleMarker([t.lat, t.lng], {
          radius: 4,
          color: "#ff6600",
        }).addTo(this.previewLayer);
      });

      this._removeHandles();
      this.state = AreaHandler.State.PREVIEW;
      this._updateButtonLabel("領域確定");
      console.log(
        `👁️ 領域内 place を仮表示しました（${this.previewTowns.length} 件）`
      );
    } catch (e) {
      this.state = AreaHandler.State.SELECTING;
      this._updateButtonLabel("領域選択");
      this._createCircleAndHandles();
      console.log("🔄 PREVIEW 中断 → SELECTING に復帰しました");
    }
  }

  // ---------------------------------------------------
  // 確定（PREVIEW → IDLE）：GPX + Marker 登録
  // ---------------------------------------------------
  _commitTowns() {
    this.previewTowns.forEach((t) => {
      const trkpt = {
        lat: t.lat,
        lon: t.lng,
        name: t.name,
      };
      const added = this.selector.gpxService.addTrkpt(trkpt);
      this.selector.markerHandler.addPoint(added);
    });
    console.log(`✅ GPX + Marker 登録完了: ${this.previewTowns.length} 件`);
    this._resetAll();
  }

  // ---------------------------------------------------
  // ヘルパー：ボタンラベル更新
  // ---------------------------------------------------
  _updateButtonLabel(label) {
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.areaActionBtnId,
      label
    );
  }

  // ---------------------------------------------------
  // ヘルパー：円とハンドル作成（未定義だった部分を追加・仮定）
  // ---------------------------------------------------
  _createCircleAndHandles() {
    if (this.circleLayer) {
      this.selector.map.removeLayer(this.circleLayer);
    }
    this.circleLayer = L.circle(this.center, {
      radius: this.radius,
      color: "#3388ff",
      fillOpacity: 0.2,
    }).addTo(this.selector.map);

    if (this.centerHandle) {
      this.selector.map.removeLayer(this.centerHandle);
    }
    this.centerHandle = L.marker(this.center, {
      icon: this.centerHandleIcon,
      draggable: true,
    }).addTo(this.selector.map);
    this.centerHandle.on("drag", this._onCenterDrag.bind(this));

    // ✅ 半径ハンドルの位置を計算（初期は東方向）
    const pos = this._computeHandleLatLng(this.center, this.radius);
    if (this.radiusHandle) {
      this.selector.map.removeLayer(this.radiusHandle);
    }
    this.radiusHandle = L.marker(pos, {
      icon: this.radiusHandleIcon,
      draggable: true,
    }).addTo(this.selector.map);
    this.radiusHandle.on("drag", this._onRadiusDrag.bind(this));
  }

  // ---------------------------------------------------
  // ヘルパー：中心ハンドルドラッグ
  // ---------------------------------------------------
  _onCenterDrag(e) {
    const newCenter = e.target.getLatLng();

    // delta計算（緯度経度近似）
    const deltaLat = newCenter.lat - this.center.lat;
    const deltaLng = newCenter.lng - this.center.lng;

    this.center = newCenter;
    this.circleLayer.setLatLng(this.center);

    // 半径ハンドルを一緒に移動
    const radiusPos = this.radiusHandle.getLatLng();
    this.radiusHandle.setLatLng(
      L.latLng(radiusPos.lat + deltaLat, radiusPos.lng + deltaLng)
    );
  }

  // ---------------------------------------------------
  // ヘルパー：半径ハンドルドラッグ
  // ---------------------------------------------------
  _onRadiusDrag(e) {
    const newPos = e.target.getLatLng();

    // 新しい半径を計算（LeafletのdistanceTo使用）
    this.radius = this.center.distanceTo(newPos);

    this.circleLayer.setRadius(this.radius);
  }

  // ---------------------------------------------------
  // ヘルパー：初期半径ハンドル位置計算
  // ---------------------------------------------------
  _computeHandleLatLng(center, radius) {
    const earth = 6378137; // 地球半径 (m)
    const latRad = (center.lat * Math.PI) / 180;
    const deltaLon = (radius / (earth * Math.cos(latRad))) * (180 / Math.PI);
    return L.latLng(center.lat, center.lng + deltaLon);
  }

  // ---------------------------------------------------
  // ヘルパー：ハンドル削除
  // ---------------------------------------------------
  _removeHandles() {
    if (this.centerHandle) {
      this.selector.map.removeLayer(this.centerHandle);
      this.centerHandle = null;
    }
    if (this.radiusHandle) {
      this.selector.map.removeLayer(this.radiusHandle);
      this.radiusHandle = null;
    }
  }

  // ---------------------------------------------------
  // ヘルパー：PREVIEWクリア
  // ---------------------------------------------------
  _clearPreview() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
    this.previewTowns = [];
  }

  // ---------------------------------------------------
  // ヘルパー：全リセット（IDLEに戻る）
  // ---------------------------------------------------
  _resetAll() {
    this._clearPreview();
    if (this.circleLayer) {
      this.selector.map.removeLayer(this.circleLayer);
      this.circleLayer = null;
    }
    this._removeHandles();
    this.center = null;
    this.radius = 1000;
    this.state = AreaHandler.State.IDLE;
    this.selector.currentMode = null; // モードリセット（必要に応じて調整）
    this.selector.updateModeUI();
    this._updateButtonLabel("領域追加");
  }
}
