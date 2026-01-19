/**
 * marker-history.js
 * 履歴データの永続化（localStorage）、重複排除、カウントアップ、
 * および各コンポーネントへの更新通知を管理する。
 */
import { markerEvents, MarkerEventTypes, dispatchMarkerEvent } from "./marker-events.js";

class MarkerHistory {
  constructor(storageKey = "leaflet_search_history_keyword_only") {
    this.storageKey = storageKey;
  }

  /**
   * 全履歴を取得
   */
  getAll() {
    try {
      const json = localStorage.getItem(this.storageKey);
      return json ? JSON.parse(json) : [];
    } catch (e) {
      console.error("履歴の読み込みに失敗しました:", e);
      return [];
    }
  }

  /**
   * 単一アイテムが条件に合致するか判定する
   * SearchControl のフィルタリングでも共通利用するロジック
   */
  match(item, query, pCode = "", mCode = "") {
    // 1. キーワード判定 (name または extensions.keyword)
    if (query) {
      const q = query.toLowerCase();
      const name = (item.name || "").toLowerCase();
      const keyword = (item.extensions?.keyword || "").toLowerCase();
      if (!name.includes(q) && !keyword.includes(q)) return false;
    }

    // 2. 自治体コード判定
    const targetCode = item.extensions?.muniCd5;
    if (pCode || mCode) {
      if (!targetCode) return false;
      // 都道府県コード (pCode) は前方一致
      if (pCode && !targetCode.startsWith(pCode)) return false;
      // 市区町村コード (mCode) は完全一致
      if (mCode && targetCode !== mCode) return false;
    }

    return true;
  }

  /**
   * 条件による履歴内検索
   */
  search(query, pCode = "", mCode = "") {
    return this.getAll().filter(item => this.match(item, query, pCode, mCode));
  }

  /**
   * 履歴の保存・更新・カウントアップ
   * @param {Object} newItem 保存対象のポイントデータ
   * @returns {Object} 保存・正規化されたデータ
   */
  save(newItem) {
    let history = this.getAll();
    const now = new Date().toISOString();

    // 1. 同一地点の判定 (IDまたは座標の近似値)
    let existingIndex = history.findIndex(h => 
      (newItem._id && h._id === newItem._id) || 
      (Math.abs(h.lat - newItem.lat) < 0.0001 && Math.abs(h.lon - newItem.lon) < 0.0001)
    );

    let targetItem;

    if (existingIndex > -1) {
      // --- 既存あり：情報の更新とカウントアップ ---
      const oldItem = history[existingIndex];
      
      // 基本情報は新しいもので上書き、extensionsはマージ
      targetItem = { ...oldItem, ...newItem };
      targetItem.extensions = { 
        ...oldItem.extensions,
        ...newItem.extensions,
        count: (oldItem.extensions?.count || 0) + 1, // カウントアップ
        timestamp: now 
      };

      // 古い位置から削除（最新にするため後でunshiftする）
      history.splice(existingIndex, 1);
    } else {
      // --- 新規登録 ---
      const { source, ...rest } = newItem; // source等のメタデータは除外
      targetItem = {
        ...rest,
        _id: newItem._id || "ID_" + Date.now(),
        extensions: { 
          ...newItem.extensions, 
          count: 1, 
          timestamp: now 
        }
      };
    }

    // 2. 先頭に追加して保存（最新順）
    history.unshift(targetItem);
    
    // 最大保存件数の制限
    if (history.length > 2000) {
      history = history.slice(0, 2000);
    }

    localStorage.setItem(this.storageKey, JSON.stringify(history));

    // 3. 📣 外部へ通知
    dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: targetItem });

    return { ...targetItem, source: "history" };
  }

  /**
   * 履歴から削除
   */
  delete(item) {
    let history = this.getAll();
    const beforeLength = history.length;

    history = history.filter(h => {
      if (item._id && h._id === item._id) return false;
      return !(
        Math.abs(h.lat - item.lat) < 0.0001 &&
        Math.abs(h.lon - item.lon) < 0.0001
      );
    });

    if (history.length !== beforeLength) {
      localStorage.setItem(this.storageKey, JSON.stringify(history));
      // 📣 削除されたことを通知
      dispatchMarkerEvent(MarkerEventTypes.POINT_DELETED, { point: item });
    }
  }

  /**
   * 自治体コードによるフィルタリング（足跡用）
   */
  getByMuniCd(muniCd) {
    if (!muniCd) return [];
    return this.getAll().filter(h => h.extensions?.muniCd5 === muniCd);
  }
}

// シングルトンとして公開
export const markerHistory = new MarkerHistory();