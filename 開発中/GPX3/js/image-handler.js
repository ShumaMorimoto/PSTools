// image-handler.js（町字追加と同じ3状態モデル + MODE連動）

export default class ImageHandler {
  static State = {
    IDLE: "idle", // 何もしていない
    SELECTING: "selecting", // 編集中（フォーカスあり）
    PREVIEW: "preview", // 確定待ち（フォーカスアウト）
  };

  constructor(selector) {
    this.selector = selector;
    this.state = ImageHandler.State.IDLE;
  }

  init() {
    this.initImageHandlers();
  }

  _logState() {
    console.log(
      `%c[ImageHandler] MODE=${this.selector.currentMode}  STATUS=${this.state}`,
      "color: #4CAF50; font-weight: bold;"
    );
  }

  // ---------------------------------------------------
  // ✅ 画像ボタン押下（開始 / キャンセル / 確定）
  // ---------------------------------------------------
  onImageButtonClick() {
    switch (this.state) {
      case ImageHandler.State.IDLE:
        // ✅ 初回：画像追加
        this._openImageInput();
        break;

      case ImageHandler.State.SELECTING:
        // ✅ キャンセル（編集破棄）
        this._resetToIdle();
        break;

      case ImageHandler.State.PREVIEW:
        // ✅ 確定
        this._confirmImage();
        break;
    }
  }

  // ---------------------------------------------------
  // ✅ input を開く（初回）
  // ---------------------------------------------------
  _openImageInput() {
    const input = document.getElementById(this.selector.controls.imageInputId);
    input.click();
  }

  // ---------------------------------------------------
  // ✅ 編集モードへ（SELECTING）
  // ---------------------------------------------------
  _enterEditMode() {
    this.selector.currentMode = this.selector.constructor.Mode.IMAGE_MODE;
    this.state = ImageHandler.State.SELECTING;

    this.enableEditing();
    this.selector.updateModeUI();

    this.selector.uiManager.setButtonLabel(
      this.selector.controls.imageActionBtnId,
      "キャンセル"
    );

    this._logState(); // ← 追加
  }

  // ---------------------------------------------------
  // ✅ PREVIEW → 確定（IDLEへ）
  // ---------------------------------------------------
  _confirmImage() {
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this.state = ImageHandler.State.IDLE;

    this._logState(); // ← 追加

    this.disableEditing();
    this.selector.updateModeUI();

    this.selector.uiManager.setButtonLabel(
      this.selector.controls.imageActionBtnId,
      "画像追加"
    );
    this._logState(); // ← 追加
  }

  _resetToIdle() {
    this.selector.currentMode = this.selector.constructor.Mode.DEFAULT;
    this.state = ImageHandler.State.IDLE;

    this.disableEditing();

    // ✅ 全消し
    try {
      this.selector.imgGroup.clearLayers();
    } catch (e) {
      console.warn("clearLayers failed", e);
    }
    this.selector.updateModeUI();

    // ✅ 画像が無いので「画像追加」
    this.selector.uiManager.setButtonLabel(
      this.selector.controls.imageActionBtnId,
      "画像追加"
    );
  }

  // ---------------------------------------------------
  // ✅ input / drop で画像追加
  // ---------------------------------------------------
  initImageHandlers() {
    const input = document.getElementById(this.selector.controls.imageInputId);

    input.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (!file) return;

      this.onImageSelected(file);
      e.target.value = "";
    });

    const mapArea = document.getElementById(this.selector.mapId);

    mapArea.addEventListener("dragover", (e) => e.preventDefault());
    mapArea.addEventListener("drop", (e) => {
      e.preventDefault();
      const file = e.dataTransfer.files[0];
      if (file && file.type.startsWith("image/")) {
        this.onImageSelected(file);
      }
    });
  }

  // ---------------------------------------------------
  // ✅ 画像ファイルが選ばれた
  // ---------------------------------------------------
  onImageSelected(file) {
    this._loadImageFile(file);
  }

  // ---------------------------------------------------
  // ✅ File → DataURL → addImageToMap
  // ---------------------------------------------------
  _loadImageFile(file) {
    const reader = new FileReader();
    reader.onload = (event) => {
      this.addImageToMap(event.target.result);

      // ✅ 画像追加後は SELECTING（編集中）へ
      this._enterEditMode();
    };
    reader.readAsDataURL(file);
  }

  // ---------------------------------------------------
  // ✅ 画像追加（常に 1 枚だけ）
  // ---------------------------------------------------
  addImageToMap(dataUrl) {
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

    try {
      const img = L.distortableImageOverlay(dataUrl, {
        actions: [L.ScaleAction, L.OpacityAction, L.DeleteAction],
        corners: initialCorners,
        selected: true,
      });

      img.on("add", () => img.setOpacity(0.3));

      // ✅ フォーカスあり → SELECTING
      img.on("select", () => {
        if (this.state === ImageHandler.State.IDLE) return;

        this.selector.currentMode = this.selector.constructor.Mode.IMAGE_MODE;
        this.state = ImageHandler.State.SELECTING;

        this.selector.uiManager.setButtonLabel(
          this.selector.controls.imageActionBtnId,
          "キャンセル"
        );
        this.selector.updateModeUI();
      });

      // ✅ フォーカス外れ → PREVIEW
      img.on("deselect", () => {
        if (this.state === ImageHandler.State.IDLE) return;

        this.selector.currentMode = this.selector.constructor.Mode.IMAGE_MODE;
        this.state = ImageHandler.State.PREVIEW;

        this.selector.uiManager.setButtonLabel(
          this.selector.controls.imageActionBtnId,
          "画像確定"
        );
        this.selector.updateModeUI();
        this._logState(); // ← 追加
      });

      img.on("delete", () => {
        try {
          this.selector.imgGroup.removeLayer(img);
        } catch (e) {
          console.warn("removeLayer failed", e);
        }
        this._resetToIdle();
      });

      this.selector.imgGroup.addLayer(img);
    } catch (e) {
      console.error("addImageToMap error", e);
      alert("画像追加に失敗しました（コンソールを確認してください）。");
    }
  }

  enableEditing() {
    try {
      this.selector.imgGroup.eachLayer((layer) => {
        if (layer.editing?.enable) layer.editing.enable();
      });
    } catch (e) {
      console.warn("enableEditing failed", e);
    }
  }

  disableEditing() {
    try {
      this.selector.imgGroup.eachLayer((layer) => {
        if (layer.editing?.disable) layer.editing.disable();
        if (layer.deselect) layer.deselect();
      });
    } catch (e) {
      console.warn("disableEditing failed", e);
    }
  }

  hasImage() {
    return (
      this.selector.imgGroup && this.selector.imgGroup.getLayers().length > 0
    );
  }

  handleMapClick(e) {
    // IMAGE_MODE 中はクリックを無視（画像編集は画像側で完結）
  }
}
