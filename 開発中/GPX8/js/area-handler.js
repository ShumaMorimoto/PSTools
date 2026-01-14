import { geoService } from "./components/geo-service.js";
import { notify } from "./api-utils.js";

export default class AreaHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PROCESSING: "processing", // 💡 追加
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle: { label: "領域追加", canCancel: false },
    selecting: { label: "領域確定", canCancel: true },
    processing: { label: "取得中...", canCancel: false }, // 💡 status-processingが適用される
    preview: { label: "登録", canCancel: true },
  };

  constructor(selector) {
    this.selector = selector;
    this.state = AreaHandler.State.IDLE;

    // 一時データ
    this.circleLayer = null;
    this.previewLayer = null;
    this.previewTowns = [];

    // 円編集
    this.center = null;
    this.radius = 500;
    this.centerHandle = null;
    this.radiusHandle = null;

    // 💡 CSS定義を活かすため、インラインスタイルを排除
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

  init() {}

  // ---------------------------------------------------
  // ボタン押下（開始 / プレビュー実行 / 登録確定）
  // ---------------------------------------------------
  onActionButtonClick() {
    switch (this.state) {
      case AreaHandler.State.IDLE:
        this._start();
        break;
      case AreaHandler.State.SELECTING:
        this._preview();
        break;
      case AreaHandler.State.PREVIEW:
        this._confirm();
        break;
    }
  }

  // ---------------------------------------------------
  // キャンセル
  // ---------------------------------------------------
  handleCancel() {
    if (this.state === AreaHandler.State.IDLE) return;

    if (this.state === AreaHandler.State.PREVIEW) {
      this._clearPreview();
      this._createCircleAndHandles(); // ハンドルを再表示
      this.changeState(AreaHandler.State.SELECTING);
      return;
    }

    this._clearAllLayers();
    this.changeState(AreaHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // 地図クリック
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.AREA_MODE)
      return;

    if (this.state === AreaHandler.State.SELECTING) {
      this.center = e.latlng;
      this._createCircleAndHandles();
    }
  }

  // ---------------------------------------------------
  // 状態遷移（セレクターへ通知してCSSクラスを切り替える）
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;
    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...AreaHandler.StateInfo[newState],
    });
  }

  _start() {
    this.selector.setMode(this.selector.constructor.Mode.AREA_MODE);
    this.center = this.selector.map.getCenter();
    this._createCircleAndHandles();
    this.changeState(AreaHandler.State.SELECTING);
  }

  // 💡 非同期処理の前後で状態を制御
  async _preview() {
    if (!this.center) return;

    // 1. まず状態を「処理中」に変える
    this.changeState(AreaHandler.State.PROCESSING);

    // 2. 💡 重要：通信開始と同時にハンドルを消して、円を動かせないようにする
    this._removeHandles();

    try {
      this._clearPreview();
      this.previewLayer = L.layerGroup().addTo(this.selector.map);

      const { lat, lng: lon } = this.center;
      this.previewTowns = await geoService.fetchAreaTowns(
        { lat, lon },
        this.radius
      );

      this.previewTowns.forEach((t) => {
        L.circleMarker([t.lat, t.lon], {
          radius: 4,
          color: "#ff6600",
        }).addTo(this.previewLayer);
      });

      // 成功時はそのまま PREVIEW 状態へ
      this.changeState(AreaHandler.State.PREVIEW);
    } catch (e) {
      console.error("AreaTowns取得失敗:", e);
      notify("❌ データ取得に失敗しました");

      // 3. 💡 失敗した場合は、ハンドルを再作成して編集可能な状態に戻す
      this._createCircleAndHandles();
      this.changeState(AreaHandler.State.SELECTING);
    }
  }
  
  _confirm() {
    if (this.previewTowns.length === 0) return;

    const pts = this.previewTowns.map((t) => ({
      lat: t.lat,
      lon: t.lon,
      name: t.name,
    }));

    this.selector.addPoints(pts);
    this.selector.reorderMarkers();

    this._clearAllLayers();
    this.changeState(AreaHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // レイヤ・描画管理
  // ---------------------------------------------------
  _clear() {
    this.center = null;
    this.radius = 500;
  }

  _clearAllLayers() {
    this._clearPreview();
    if (this.circleLayer) {
      this.selector.map.removeLayer(this.circleLayer);
      this.circleLayer = null;
    }
    this._removeHandles();
  }

  _clearPreview() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
    this.previewTowns = [];
  }

  _createCircleAndHandles() {
    if (this.circleLayer) this.selector.map.removeLayer(this.circleLayer);

    this.circleLayer = L.circle(this.center, {
      radius: this.radius,
      color: "#3388ff",
      fillOpacity: 0.2,
    }).addTo(this.selector.map);

    if (this.centerHandle) this.selector.map.removeLayer(this.centerHandle);
    this.centerHandle = L.marker(this.center, {
      icon: this.centerHandleIcon,
      draggable: true,
    }).addTo(this.selector.map);
    this.centerHandle.on("drag", this._onCenterDrag.bind(this));

    const pos = this._computeHandleLatLng(this.center, this.radius);
    if (this.radiusHandle) this.selector.map.removeLayer(this.radiusHandle);
    this.radiusHandle = L.marker(pos, {
      icon: this.radiusHandleIcon,
      draggable: true,
    }).addTo(this.selector.map);
    this.radiusHandle.on("drag", this._onRadiusDrag.bind(this));
  }

  _onCenterDrag(e) {
    const oldCenter = this.center;
    this.center = e.target.getLatLng();
    this.circleLayer.setLatLng(this.center);
    const rPos = this.radiusHandle.getLatLng();
    this.radiusHandle.setLatLng(
      L.latLng(
        rPos.lat + (this.center.lat - oldCenter.lat),
        rPos.lng + (this.center.lng - oldCenter.lng)
      )
    );
  }

  _onRadiusDrag(e) {
    this.radius = this.center.distanceTo(e.target.getLatLng());
    this.circleLayer.setRadius(this.radius);
  }

  _computeHandleLatLng(center, radius) {
    const earth = 6378137;
    const latRad = (center.lat * Math.PI) / 180;
    const deltaLon = (radius / (earth * Math.cos(latRad))) * (180 / Math.PI);
    return L.latLng(center.lat, center.lng + deltaLon);
  }

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
}
