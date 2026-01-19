// marker/marker-events.js
export const markerEvents = new EventTarget();

/**
 * 通知の種類を定数化
 */
export const MarkerEventTypes = {
    POINT_UPDATED:  "point-updated",  // 属性や位置が変わった（編集確定など）
    LIST_CHANGED:   "list-changed",   // リストの構造が変わった（本マーカーの追加・削除など）
    POINT_SELECTED: "point-selected", // 「しるし」がついた、または「足跡」が選ばれた（←追加）
};

/**
 * 更新イベントを発火させる共通関数
 * dispatchMarkerEvent(MarkerEventTypes.POINT_SELECTED, item); のように使う
 */
export function dispatchMarkerEvent(type, detail) {
    markerEvents.dispatchEvent(new CustomEvent(type, { detail }));
}