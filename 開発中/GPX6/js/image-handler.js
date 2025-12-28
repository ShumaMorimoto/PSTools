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

    this.tempData = null; // 画像の DataURL
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  init() {
    this._initImageInputHandlers();
  }

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
  // キャンセル（テンプレ準拠）
  // ---------------------------------------------------
  handleCancel() {
    if (this.state === ImageHandler.State.IDLE) return;

    // ① キャンセルは編集破棄 → 画像を消す
    try {
      this.selector.imgGroup.clearLayers();
    } catch (e) {
      console.warn("clearLayers failed", e);
    }

    // ② 状態遷移は必ず changeState を通す
    this.changeState(ImageHandler.State.IDLE);

    // ③ モードは DEFAULT に戻す
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }
  // ---------------------------------------------------
  // Map click（画像編集は画像側で完結）
  // ---------------------------------------------------
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
      mode: this.selector.currentMode,
      state: newState,
      ...ImageHandler.StateInfo[newState],
    });
  }

  // ---------------------------------------------------
  // 内部ロジック（テンプレ準拠）
  // ---------------------------------------------------

  // IDLE → SELECTING（画像追加開始）
  _start() {
    const input = document.getElementById(this.selector.controls.imageInputId);
    input.click();
  }

  // SELECTING → PREVIEW（フォーカス外れ）
  _preview() {
    this.changeState(ImageHandler.State.PREVIEW);
  }

  // PREVIEW / SELECTING → IDLE（確定）
  _confirm() {
    this.changeState(ImageHandler.State.IDLE);
    this.selector.setMode(this.selector.constructor.Mode.DEFAULT);
  }

  // ---------------------------------------------------
  // 内部処理
  // ---------------------------------------------------

  _clear() {
    this.tempData = null;
    this._disableEditing(); // 編集終了
    // 画像(imgGroup)は消さない
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
  // input / drop で画像追加
  // ---------------------------------------------------
  _initImageInputHandlers() {
    const input = document.getElementById(this.selector.controls.imageInputId);

    input.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (!file) return;

      this._loadImageFile(file);
      e.target.value = "";
    });

    const mapArea = document.getElementById(this.selector.mapId);

    mapArea.addEventListener("dragover", (e) => e.preventDefault());
    mapArea.addEventListener("drop", (e) => {
      e.preventDefault();
      const file = e.dataTransfer.files[0];
      if (file && file.type.startsWith("image/")) {
        this._loadImageFile(file);
      }
    });
  }

  // File → DataURL
  _loadImageFile(file) {
    const reader = new FileReader();
    reader.onload = (event) => {
      this.tempData = event.target.result;
      this._addImageToMap(this.tempData);
      this.changeState(ImageHandler.State.SELECTING);
    };
    reader.readAsDataURL(file);
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

    //    img.on("select", () => {
    //      if (this.state === ImageHandler.State.IDLE) return;
    //      this.changeState(ImageHandler.State.SELECTING);
    //    });

    //    img.on("deselect", () => {
    //      if (this.state === ImageHandler.State.IDLE) return;
    //      this.changeState(ImageHandler.State.PREVIEW);
    //    });

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
      });
    } catch (e) {
      console.warn("disableEditing failed", e);
    }
  }
}
