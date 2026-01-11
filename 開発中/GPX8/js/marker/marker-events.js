// marker/marker-events.js
export const markerEvents = new EventTarget();

// 通知の種類を定数化しておくと安全です
export const MarkerEventTypes = {
    POINT_UPDATED: "point-updated", // 属性や位置が変わった
    LIST_CHANGED: "list-changed",   // 追加・削除・並び替えなどでリスト構造が変わった
};

/**
 * 更新イベントを発火させる共通関数
 */
export function dispatchMarkerEvent(type, detail) {
    markerEvents.dispatchEvent(new CustomEvent(type, { detail }));
}