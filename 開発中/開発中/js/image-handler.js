// image-handler.js

export default class ImageHandler {
  constructor(selector) {
    this.selector = selector;
  }

  // ✅ MapSelector の init() 呼び出しに合わせて名称変更
  init() {
    this.initImageHandlers();
  }

  initImageHandlers() {
    document
      .getElementById(this.selector.controls.imageInputId)
      .addEventListener("change", (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (event) => {
          this.addImageToMap(event.target.result);
          e.target.value = "";
        };
        reader.readAsDataURL(file);
      });

    const mapArea = document.getElementById(this.selector.mapId);
    mapArea.addEventListener("dragover", (e) => {
      e.preventDefault();
    });
    mapArea.addEventListener("drop", (e) => {
      e.preventDefault();
      const file = e.dataTransfer.files[0];
      if (file && file.type.startsWith("image/")) {
        const reader = new FileReader();
        reader.onload = (event) => {
          this.addImageToMap(event.target.result);
        };
        reader.readAsDataURL(file);
      }
    });
  }

  addImageToMap(url) {
    if (this.selector.isLocked) {
      this.toggleLockMode(); // 自動的にロック解除
    }

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
      const img = L.distortableImageOverlay(url, {
        actions: [
          L.ScaleAction,
          L.OpacityAction,
          L.DeleteAction,
        ],
        corners: initialCorners,
        selected: true,
      });

      img.on("add", () => {
        img.setOpacity(0.3);
      });

      img.on("delete", () => {
        try {
          this.selector.imgGroup.removeLayer(img);
        } catch (e) {
          console.warn("removeLayer failed", e);
        }
      });

      this.selector.imgGroup.addLayer(img);
    } catch (e) {
      console.error("addImageToMap error", e);
      alert("画像追加に失敗しました（コンソールを確認してください）。");
    }
  }

  toggleLockMode() {
    this.selector.isLocked = !this.selector.isLocked;
    const btn = document.getElementById(this.selector.controls.toggleLockBtnId);
    const mapDiv = document.getElementById(this.selector.mapId);

    if (this.selector.isLocked) {
      btn.innerHTML = '<i class="fas fa-lock"></i> <span>確定済</span>';
      btn.classList.add("locked");
      mapDiv.classList.add("map-locked");

      try {
        this.selector.imgGroup.eachLayer((layer) => {
          try {
            if (layer.editing && typeof layer.editing.disable === "function")
              layer.editing.disable();
            if (typeof layer.deselect === "function") layer.deselect();
          } catch (err) {
            console.warn("layer disable/deselect failed", err);
          }
        });
      } catch (e) {}
    } else {
      btn.innerHTML =
        '<i class="fas fa-lock-open"></i> <span>位置調整モード</span>';
      btn.classList.remove("locked");
      mapDiv.classList.remove("map-locked");

      try {
        this.selector.imgGroup.eachLayer((layer) => {
          try {
            if (layer.editing && typeof layer.editing.enable === "function")
              layer.editing.enable();
          } catch (err) {
            console.warn("layer enable failed", err);
          }
        });
      } catch (e) {}
    }
  }
}