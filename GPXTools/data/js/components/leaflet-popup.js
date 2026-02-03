export function createPopupContent(
  data,
  marker,
  { onSave, onUpdateAddress, onCopy } // onDelete を削除
) {
  const container = document.createElement("div");
  container.className = "popup-card";
  container.setAttribute("data-mode", "show");

  L.DomEvent.disableClickPropagation(container);

  const lat = data.lat?.toFixed(5) || "?";
  const lon = (data.lon || data.lng)?.toFixed(5) || "?";
  const initialKeyword = data.extensions?.keyword || "";

  container.innerHTML = `
    <div class="p-header" id="p-header-coord">📍 ${lat}, ${lon}</div>
    <div class="p-content">
      <div class="view-mode">
        <div class="p-title">${data.name || "名称未設定"}</div>
        <div class="p-desc">${data.desc || "---"}</div>
        <div class="p-tag">${initialKeyword ? `# ${initialKeyword}` : ""}</div>
      </div>
      <div class="edit-mode">
        <label class="p-label">履歴名称</label>
        <input type="text" class="p-input" name="name" value="${data.name || ""}">
        <label class="p-label">備考</label>
        <textarea class="p-input" name="desc" rows="2">${data.desc || ""}</textarea>
        <label class="p-label">キーワード</label>
        <input type="text" class="p-input" name="keyword" value="${initialKeyword}">
      </div>
    </div>
    <div class="p-footer">
      <button class="btn-icon btn-update-trigger" title="住所照会">🔄</button>
      <div class="p-btns-right">
        <button class="btn-s btn-edit view-mode">編集</button>
        <button class="btn-s view-mode btn-close-popup">戻る</button>
        <button class="btn-s edit-mode btn-primary btn-save">保存</button>
        <button class="btn-s edit-mode btn-cancel-edit">戻る</button>
      </div>
    </div>
  `;

  // イベント設定
  container.querySelector("#p-header-coord").onclick = () => onCopy?.(`${lat}, ${lon}`);
  container.querySelector(".btn-update-trigger").onclick = () => onUpdateAddress();
  container.querySelector(".btn-edit").onclick = () => container.setAttribute("data-mode", "editable");
  container.querySelector(".btn-close-popup").onclick = () => marker.closePopup();
  container.querySelector(".btn-cancel-edit").onclick = () => container.setAttribute("data-mode", "show");

  container.querySelector(".btn-save").onclick = () => {
    const nextName = container.querySelector('input[name="name"]').value;
    const nextDesc = container.querySelector('textarea[name="desc"]').value;
    const nextKeyword = container.querySelector('input[name="keyword"]').value;

    onSave({
      name: nextName,
      desc: nextDesc,
      extensions: {
        ...(data.extensions || {}),
        keyword: nextKeyword,
      },
    });

    // 表示更新
    container.querySelector(".view-mode .p-title").textContent = nextName || "名称未設定";
    container.querySelector(".view-mode .p-desc").textContent = nextDesc || "---";
    container.querySelector(".view-mode .p-tag").textContent = nextKeyword ? `# ${nextKeyword}` : "";

    // 内部データ更新
    if (!data.extensions) data.extensions = {};
    data.name = nextName;
    data.desc = nextDesc;
    data.extensions.keyword = nextKeyword;

    container.setAttribute("data-mode", "show");
  };

  return container;
}