// marker-address.js
import { fetchAddressAsync } from "./../api-utils.js";

export default class MarkerAddress {
  constructor(handler) {
    this.handler = handler;
    this.requestSeq = 0;
    this.seqTable = new Map(); // key: point, value: seq
  }

  // ---------------------------------------------------
  // reFetchAllAddresses
  // ---------------------------------------------------
  reFetchAllAddresses() {
    const pts = this.handler.getPoints();
    pts.forEach((tp) => this.updateAddress(tp));
  }

  // ---------------------------------------------------
  // updateAddress
  // ---------------------------------------------------
  updateAddress(point) {
    const seq = ++this.requestSeq;
    this.seqTable.set(point, seq);

    fetchAddressAsync(point)
      .then((address) => this.applyAddress(point, address, seq))
      .catch((e) => console.warn("住所取得失敗", e));
  }
  applyAddress(point, address, seq) {
    if (this.seqTable.get(point) !== seq) return;

    // 基本となる更新オブジェクト
    const updateData = {
      desc: address.display_name || "",
      extensions: address.address || {},
    };

    // nameが存在する場合のみ、更新用オブジェクトにキーを追加する
    if (address.name) {
      updateData.name = address.name;
    }

    this.handler.updatePoint(point, updateData);
  }
}
