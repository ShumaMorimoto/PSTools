import { fetchOverpassPlaces } from "./api-utils.js";

export default class AreaHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PROCESSING: "processing",
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle: { label: "領域追加", canCancel: false },
    selecting: { label: "領域選択", canCancel: true },
    processing: { label: "(処理中)", canCancel: false },
    preview: { label: "領域確定", canCancel: true },
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
  // ボタン押下（開始 / PREVIEW / 確定）
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

      default:
        break;
    }
  }

  // ---------------------------------------------------
  // キャンセル
  // ---------------------------------------------------
  handleCancel() {
    if (this.state === AreaHandler.State.IDLE) return;

    // キャンセルは “領域破棄”
    this._clearAllLayers();

    this.changeState(AreaHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // 地図クリック（SELECTING → PREVIEW）
  // ---------------------------------------------------
  async handleMapClick(e) {
    if (this.selector.currentMode !== this.selector.constructor.Mode.AREA_MODE)
      return;

    if (this.state === AreaHandler.State.SELECTING) {
      if (!this.center) {
        this.center = e.latlng;
        this._createCircleAndHandles();
      }
      await this._preview();
    }
  }

  // ---------------------------------------------------
  // 状態遷移
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    switch (newState) {
      case AreaHandler.State.IDLE:
        this._clear();
        break;

      case AreaHandler.State.SELECTING:
        this._prepareSelecting();
        break;

      case AreaHandler.State.PREVIEW:
        this._preparePreview();
        break;
    }

    this.selector.onHandlerStateChanged({
      mode: this.selector.currentMode,
      state: newState,
      ...AreaHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // IDLE → SELECTING
  // ---------------------------------------------------
  _start() {
    this.selector.setMode(this.selector.constructor.Mode.AREA_MODE);

    this.center = this.selector.map.getCenter();
    this._createCircleAndHandles();

    this.changeState(AreaHandler.State.SELECTING);
  }

  // ---------------------------------------------------
  // SELECTING → PREVIEW
  // ---------------------------------------------------
  async _preview() {
    if (!this.center) return;

    this._clearPreview();

    this.previewLayer = L.layerGroup().addTo(this.selector.map);
    this.previewTowns = [];

    try {
      this.changeState(AreaHandler.State.PROCESSING);

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

      this.changeState(AreaHandler.State.PREVIEW);
    } catch (e) {
      this.changeState(AreaHandler.State.SELECTING);
    }
  }

  // ---------------------------------------------------
  // PREVIEW → IDLE（確定）
  // ---------------------------------------------------
  _confirm() {
    const pts = this.previewTowns.map((t) => ({
      lat: t.lat,
      lon: t.lng,
      name: t.name,
    }));

    this.selector.addPoints(pts);
    this.selector.reorderMarkers()

    // 完了後は領域破棄
    this._clearAllLayers();

    this.changeState(AreaHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // 一時データのクリア（IDLE 遷移時）
  // ---------------------------------------------------
  _clear() {
    this.center = null;
    this.radius = 500;
  }

  // ---------------------------------------------------
  // SELECTING 準備
  // ---------------------------------------------------
  _prepareSelecting() {
    this.selector.setMode(this.selector.constructor.Mode.AREA_MODE);
  }

  // ---------------------------------------------------
  // PREVIEW 準備
  // ---------------------------------------------------
  _preparePreview() {
    this.selector.setMode(this.selector.constructor.Mode.AREA_MODE);
  }

  // ---------------------------------------------------
  // レイヤ削除（キャンセル・確定）
  // ---------------------------------------------------
  _clearAllLayers() {
    this._clearPreview();

    if (this.circleLayer) {
      this.selector.map.removeLayer(this.circleLayer);
      this.circleLayer = null;
    }

    this._removeHandles();
  }

  // ---------------------------------------------------
  // PREVIEW レイヤ削除
  // ---------------------------------------------------
  _clearPreview() {
    if (this.previewLayer) {
      this.selector.map.removeLayer(this.previewLayer);
      this.previewLayer = null;
    }
    this.previewTowns = [];
  }

  // ---------------------------------------------------
  // 円とハンドル
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

  _onCenterDrag(e) {
    const newCenter = e.target.getLatLng();

    const deltaLat = newCenter.lat - this.center.lat;
    const deltaLng = newCenter.lng - this.center.lng;

    this.center = newCenter;
    this.circleLayer.setLatLng(this.center);

    const radiusPos = this.radiusHandle.getLatLng();
    this.radiusHandle.setLatLng(
      L.latLng(radiusPos.lat + deltaLat, radiusPos.lng + deltaLng)
    );
  }

  _onRadiusDrag(e) {
    const newPos = e.target.getLatLng();
    this.radius = this.center.distanceTo(newPos);
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
