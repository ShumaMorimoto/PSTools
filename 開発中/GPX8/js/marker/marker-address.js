import { geoService } from "../components/geo-service.js";
import { dispatchMarkerEvent, MarkerEventTypes } from "./marker-events.js";

/**
 * マーカー（地点）の住所解決と、それに伴うイベント通知を管理するクラス。
 * 「Point（データ）中心」の設計により、UI（マーカーインスタンス）への直接的な依存を排除している。
 */
export default class MarkerAddress {
  constructor(handler) {
    this.handler = handler;
    // 通信の追い越し（古いリクエストの結果で新しい状態を上書きすること）を防ぐためのシーケンス管理
    this.requestSeq = 0;
    this.seqTable = new Map();
  }

  /**
   * 全ポイントの住所を再取得（一括更新用）
   */
  reFetchAllAddresses() {
    const pts = this.handler.getPoints();
    pts.forEach((tp) => this.updateAddress(tp));
  }

  /**
   * 特定のポイントの住所を非同期で更新。
   * geoService によって point の中身が直接書き換えられ、最新の状態のみが通知される。
   * @param {object} point - GPXモデル内のトラックポイント参照
   */
  async updateAddress(point) {
    // リクエストごとにユニークな番号を振り、この地点の最新リクエストとして記録
    const seq = ++this.requestSeq;
    this.seqTable.set(point, seq);

    try {
      // 1. 各サービスに point 参照を渡して直接更新してもらう
      // geoService 内部で point.name や point.extensions が書き換わる
      await geoService.resolveAddress(point);

      // 2. 完了時、自分がまだ「最新のリクエスト」であるかを確認（追い越しガード）
      // ドラッグ中などで次のリクエストが既に走っている場合は、この通知をスキップする
      if (this.seqTable.get(point) === seq) {
        // 全世界（HandlerやListPanelなど）に「このpointが最新状態になった」と通知
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point });
      }
    } catch (e) {
      console.warn("MarkerAddress: 住所解決プロセスでエラーが発生しました", e);
    }
  }
}