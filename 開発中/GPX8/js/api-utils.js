// api-utils.js (最終統合版)

// --- Toast 関連 ---
let toastEl = null;
export function initToast(el) {
  toastEl = el;
}

export function notify(message, duration = 1500) {
  if (!toastEl) return;
  toastEl.textContent = message;
  toastEl.classList.remove("hidden");
  toastEl.classList.add("show");
  setTimeout(() => {
    toastEl.classList.remove("show");
    toastEl.classList.add("hidden");
  }, duration);
}

// --- File IO 関連 ---
export const FileService = {
  /**
   * ファイルを読み込む (Promise)
   */
  read: (file, mode = "text") => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => resolve(e.target.result);
      reader.onerror = (e) => {
        notify("ファイルの読み込みに失敗しました");
        reject(e);
      };

      if (mode === "dataUrl") reader.readAsDataURL(file);
      else reader.readAsText(file);
    });
  },

  /**
   * ファイルを保存する
   * @param {string|Blob} content - 保存する内容
   * @param {Object} options - { filename, mimeType, extension }
   */
  save: async (content, { filename, mimeType, extension }) => {
    try {
      if (window.showSaveFilePicker) {
        const handle = await window.showSaveFilePicker({
          suggestedName: filename,
          types: [{
            description: `${extension.toUpperCase()} File`,
            accept: { [mimeType]: [`.${extension}`] },
          }],
        });
        const writable = await handle.createWritable();
        await writable.write(content);
        await writable.close();
      } else {
        // Fallback
        const blob = content instanceof Blob ? content : new Blob([content], { type: mimeType });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectURL(url);
      }
      notify("保存しました");
      return true;
    } catch (e) {
      if (e.name === 'AbortError') return false; // キャンセル時は通知しない
      console.error(e);
      notify("保存中にエラーが発生しました");
      return false;
    }
  }
};