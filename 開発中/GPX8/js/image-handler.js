export default class ImageHandler {
  static State = {
    IDLE: "idle",
    SELECTING: "selecting",
    PREVIEW: "preview",
  };

  static StateInfo = {
    idle: { label: "画像追加", canCancel: false },
    selecting: { label: "画像確定", canCancel: true },
    preview: { label: "画像確定", canCancel: true },
  };

  constructor(selector) {
    this.selector = selector;
    this.state = ImageHandler.State.IDLE;
    this.tempData = null;
  }

  // ---------------------------------------------------
  // 初期化（onAdd だけ呼ぶ）
  // ---------------------------------------------------
  init() {}

  // ---------------------------------------------------
  // ボタン押下（テンプレ準拠）
  // ---------------------------------------------------
  onActionButtonClick() {
    switch (this.state) {
      case ImageHandler.State.IDLE:
        this._start();
        break;

      case ImageHandler.State.SELECTING:
      case ImageHandler.State.PREVIEW:
        this._confirm();
        break;
    }
  }

  // ---------------------------------------------------
  // File → DataURL
  // ---------------------------------------------------
  onFileInputClick(file) {
    const reader = new FileReader();
    reader.onload = (event) => {
      this.tempData = event.target.result;
      this._addImageToMap(this.tempData);
      this.changeState(ImageHandler.State.SELECTING);
    };
    reader.readAsDataURL(file);
  }

  // ---------------------------------------------------
  // キャンセル（テンプレ準拠）
  // ---------------------------------------------------
  handleCancel() {
    if (this.state === ImageHandler.State.IDLE) return;

    try {
      this.selector.imgGroup.clearLayers();
    } catch (e) {
      console.warn("clearLayers failed", e);
    }

    this.changeState(ImageHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  handleMapClick(e) {}

  // ---------------------------------------------------
  // 状態遷移（テンプレ準拠）
  // ---------------------------------------------------
  changeState(newState) {
    this.state = newState;

    switch (newState) {
      case ImageHandler.State.IDLE:
        this._clear();
        break;

      case ImageHandler.State.SELECTING:
        this._prepareSelecting();
        break;

      case ImageHandler.State.PREVIEW:
        this._preparePreview();
        break;
    }

    this.selector.onHandlerStateChanged({
      state: newState,
      ...ImageHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // 内部ロジック（テンプレ準拠）
  // ---------------------------------------------------
  _start() {
    this.input.click();
  }

  _preview() {
    this.changeState(ImageHandler.State.PREVIEW);
  }

  _confirm() {
    this.changeState(ImageHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // 内部処理
  // ---------------------------------------------------
  _clear() {
    this.tempData = null;
    this._disableEditing();
  }

  _prepareSelecting() {
    this.selector.setMode(this.selector.constructor.Mode.IMAGE_MODE);
    this._enableEditing();
  }

  _preparePreview() {
    this.selector.setMode(this.selector.constructor.Mode.IMAGE_MODE);
    this._disableEditing();
  }

  // ---------------------------------------------------
  // 画像追加（DistortableImageOverlay）
  // ---------------------------------------------------
  _addImageToMap(dataUrl) {
    const bounds = this.selector.map.getBounds();
    const center = bounds.getCenter();

    const height = 0.0303301719782;
    const width = 0.024354457855;

    const north = center.lat + height / 2;
    const south = center.lat - height / 2;
    const west = center.lng - width / 2;
    const east = center.lng + width / 2;

    const initialCorners = [
      L.latLng(north, west),
      L.latLng(north, east),
      L.latLng(south, west),
      L.latLng(south, east),
    ];

    const img = L.distortableImageOverlay(dataUrl, {
      actions: [L.ScaleAction, L.OpacityAction, L.DeleteAction],
      corners: initialCorners,
      selected: true,
    });

    img.on("add", () => img.setOpacity(0.3));
    img.on("delete", () => {
      this.changeState(ImageHandler.State.IDLE);
    });

    this.selector.imgGroup.addLayer(img);
  }

  // ---------------------------------------------------
  // 編集 ON/OFF
  // ---------------------------------------------------
  _enableEditing() {
    try {
      this.selector.imgGroup.eachLayer((layer) => {
        if (layer.editing?.enable) layer.editing.enable();
        if (layer.getElement()) {
          layer.getElement().style.pointerEvents = "auto";
        }
      });
    } catch (e) {
      console.warn("enableEditing failed", e);
    }
  }

  _disableEditing() {
    try {
      this.selector.imgGroup.eachLayer((layer) => {
        if (layer.editing?.disable) layer.editing.disable();
        if (layer.deselect) layer.deselect();
        if (layer.getElement()) {
          layer.getElement().style.pointerEvents = "none";
        }
      });
    } catch (e) {
      console.warn("disableEditing failed", e);
    }
  }
}
