// gpx-service.js
export default class GPXService {

  // -----------------------------
  // GPX → pointList[]
  // -----------------------------
  parseGpx(gpxText) {
    const parser = new DOMParser();
    const xml = parser.parseFromString(gpxText, "text/xml");

    // ✅ namespace を完全無視して trkpt を拾う（最強・最安定）
    const trkptNodes = xml.evaluate(
      "//*[local-name()='trkpt']",
      xml,
      null,
      XPathResult.ORDERED_NODE_SNAPSHOT_TYPE,
      null
    );

    const points = [];

    for (let i = 0; i < trkptNodes.snapshotLength; i++) {
      const pt = trkptNodes.snapshotItem(i);

      const lat = parseFloat(pt.getAttribute("lat"));
      const lon = parseFloat(pt.getAttribute("lon"));
      if (isNaN(lat) || isNaN(lon)) continue;

      const nameNode = this.findChild(pt, "name");
      const descNode = this.findChild(pt, "desc");
      const extNode  = this.findChild(pt, "extensions");

      const extended = extNode ? this.parseExtensions(extNode) : {};

      points.push({
        lat,
        lon,
        name: nameNode ? nameNode.textContent : "",
        desc: descNode ? descNode.textContent : "",
        extended
      });
    }

    return points;
  }

  // ✅ local-name() ベースで namespace 無視して検索
  findChild(parent, tag) {
    const nodes = parent.querySelectorAll("*");
    for (const n of nodes) {
      if (n.localName === tag) return n;
    }
    return null;
  }

  // ✅ extensions の子要素をすべて key-value として取り込む
  parseExtensions(extNode) {
    const result = {};
    for (const c of extNode.children) {
      result[c.localName] = c.textContent;
    }
    return result;
  }

  // -----------------------------
  // pointList[] → GPX
  // -----------------------------
  generateGpx(pointList) {
    const trkpts = pointList.map(p => `
      <trkpt lat="${p.lat}" lon="${p.lon}">
        ${p.name ? `<name>${this.escape(p.name)}</name>` : ""}
        ${p.desc ? `<desc>${this.escape(p.desc)}</desc>` : ""}
        ${this.buildExtensions(p.extended)}
      </trkpt>
    `).join("");

    return `
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1"
     creator="MapSelector"
     xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <trkseg>
      ${trkpts}
    </trkseg>
  </trk>
</gpx>
`.trim();
  }

  // ✅ extensions の書き戻し
  buildExtensions(ext) {
    if (!ext || Object.keys(ext).length === 0) return "";
    const inner = Object.entries(ext)
      .map(([k, v]) => `<${k}>${this.escape(v)}</${k}>`)
      .join("");
    return `<extensions>${inner}</extensions>`;
  }

  // ✅ XML エスケープ
  escape(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }
}