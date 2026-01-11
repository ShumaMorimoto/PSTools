// marker-address.js
import { geoService } from "../components/geo-service.js";

export default class MarkerAddress {
  constructor(handler) {
    this.handler = handler;
    this.requestSeq = 0;
    this.seqTable = new Map();
  }

  /**
   * 全ポイントの住所を再取得（一括更新）
   */
  reFetchAllAddresses() {
    const pts = this.handler.getPoints();
    pts.forEach((tp) => this.updateAddress(tp));
  }

  /**
   * 特定のポイントの住所を非同期で更新
   */
  async updateAddress(point) {
    // 古いリクエストを無視するためのシーケンス管理
    const seq = ++this.requestSeq;
    this.seqTable.set(point, seq);

    try {
      // 1. Nominatim 等から詳細な住所・施設名を取得
      const addressData = await geoService.resolveAddress(point);
      
      // 2. 国土地理院等から自治体コード等の属性情報を取得
      const resolvedPoint = await geoService.resolve(point);

      this.applyMergedData(point, addressData, resolvedPoint, seq);
    } catch (e) {
      console.warn("住所更新プロセス中にエラーが発生しました", e);
    }
  }

  /**
   * 取得したデータをマージして Core に反映
   */
  applyMergedData(point, addressData, resolvedPoint, seq) {
    // 最新のリクエストでなければ破棄（ドラッグ連発時などの不整合防止）
    if (this.seqTable.get(point) !== seq) return;

    const updateData = {
      // Nominatimの施設名を優先
      name: addressData.name || resolvedPoint.name,
      
      // Nominatimの長い住所
      desc: resolvedPoint.desc,

      // 両方の拡張情報をマージ
      extensions: {
        ...(resolvedPoint.extensions || {}), 
        ...(addressData.address || {}),      
      },
    };

    // --- ここが重要 ---
    // Core の updatePoint を呼ぶ。
    // 内部で POINT_UPDATED イベントが飛び、購読している全ての UI (List, Popup) が更新される。
    this.handler.core.updatePoint(point, updateData);
  }
}