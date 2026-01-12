import { geoService } from "../components/geo-service.js";

export default class MarkerAddress {
  constructor(handler) {
    this.handler = handler;
    this.requestSeq = 0;
    this.seqTable = new Map();
  }

  reFetchAllAddresses() {
    const pts = this.handler.getPoints();
    pts.forEach((tp) => this.updateAddress(tp));
  }

  async updateAddress(point) {
    const seq = ++this.requestSeq;
    this.seqTable.set(point, seq);

    try {
      // 1. 詳細な住所・施設名を取得 (Nominatim / 1秒制限あり)
      const addressData = await geoService.resolveAddress(point);
      
      // 2. 自治体コード等の属性情報を取得 (国土地理院 / 制限なし)
      const resolvedPoint = await geoService.resolve(point);

      this.applyMergedData(point, addressData, resolvedPoint, seq);
    } catch (e) {
      console.warn("住所更新プロセス中にエラーが発生しました", e);
    }
  }

  applyMergedData(point, addressData, resolvedPoint, seq) {
    if (this.seqTable.get(point) !== seq) return;

    // Nominatimの詳細情報と国土地理院のコード情報をマージ
    const updateData = {
      // 名前：Nominatimの施設名があれば優先、なければ市区町村名
      name: addressData.name || resolvedPoint.name,
      
      // 説明：Nominatimの長い住所
      desc: addressData.display_name || resolvedPoint.desc,

      // 拡張情報：両方のデータを合成
      extensions: {
        ...(resolvedPoint.extensions || {}), // 自治体コード類
        ...(addressData.address || {}),      // OSMの番地・郵便番号等
      },
    };

    this.handler.updatePoint(point, updateData);
  }
}