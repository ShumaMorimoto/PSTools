// marker-address.js
import { fetchAddressAsync } from "./../api-utils.js";

export default class MarkerAddress {
  constructor(core) {
    this.core = core;
    this.requestSeq = 0;
    this.seqTable = new Map(); // key: point, value: seq
  }

  // ---------------------------------------------------
  // reFetchAllAddresses
  // ---------------------------------------------------
  reFetchAllAddresses() {
    const pts = this.core.getPoints();
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

    this.core.updatePoint(point, {
      name: address.name || "",
      desc: address.display_name || "",
      extensions: address.address || {},
    });
  }
}
