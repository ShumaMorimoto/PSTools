// js/gpx-service.js

export default class GPXService {
  static TypeMap = {
    domain: { BaseType: "string", IsAttribute: true },
    maxlat: { BaseType: "decimal", IsAttribute: true },
    gpx: { BaseType: "gpxType", IsAttribute: false },
    author: { BaseType: "string", IsAttribute: true },
    minlon: { BaseType: "decimal", IsAttribute: true },
    minlat: { BaseType: "decimal", IsAttribute: true },
    id: { BaseType: "string", IsAttribute: true },
    href: { BaseType: "anyURI", IsAttribute: true },
    lon: { BaseType: "decimal", IsAttribute: true },
    lat: { BaseType: "decimal", IsAttribute: true },
    maxlon: { BaseType: "decimal", IsAttribute: true },
    version: { BaseType: "string", IsAttribute: true },
    creator: { BaseType: "string", IsAttribute: true },

    // 構造要素
    trk: { BaseType: "object", IsAttribute: false },
    trkseg: { BaseType: "object", IsAttribute: false },
    trkpt: { BaseType: "object", IsAttribute: false },
    extensions: { BaseType: "object", IsAttribute: false },
    //    extended: { BaseType: "object", IsAttribute: false }, // extendedもサポート（標準はextensionsだが）
    name: { BaseType: "string", IsAttribute: false },
    desc: { BaseType: "string", IsAttribute: false },
    // 追加の属性や要素をここに追加可能、例: ele, time, etc.
    muitiRoute: { BaseType: "string", IsAttribute: true }, // 必要に応じて追加
  };

  static GpxNamespace = "http://www.topografix.com/GPX/1/1";

  constructor(initialModel = null) {
    this.doc = document.implementation.createDocument(
      GPXService.GpxNamespace,
      "gpx",
      null
    );
    this.model = this._normalizeModel(initialModel);
  }

  // ----------------------------
  // Model Operations
  // ----------------------------

  setModel(model) {
    this.model = this._normalizeModel(model);
  }

  getModel() {
    return this.model;
  }

  // ----------------------------
  // XML/JSON Conversion
  // ----------------------------

  loadFromXml(xmlString) {
    const json = GPXService.xmlToJson(xmlString);
    this.setModel(json);
  }

  toXml() {
    if (!this.model) return "";
    return GPXService.jsonToXml(this.model, this.doc);
  }

  static jsonToXml(json, doc) {
    const root = GPXService.createElementFromObject("gpx", json, doc);
    root.setAttribute("version", "1.1");
    root.setAttribute("xmlns", GPXService.GpxNamespace);
    doc.replaceChild(root, doc.documentElement);
    const xmlString = new XMLSerializer().serializeToString(doc);
    return '<?xml version="1.0" encoding="UTF-8"?>' + xmlString;
  }

  static createElementFromObject(name, obj, doc) {
    const elem = doc.createElementNS(GPXService.GpxNamespace, name);
    if (!obj) return elem;

    Object.entries(obj).forEach(([key, value]) => {
      if (key.startsWith("_")) return; // Skip keys starting with _

      // extendedをextensionsとして出力（標準準拠）
      //      const outputKey = key === "extended" ? "extensions" : key;
      const outputKey = key;

      const typeInfo = GPXService.TypeMap[outputKey] || {
        BaseType: "string",
        IsAttribute: false,
      };

      if (typeInfo.IsAttribute) {
        elem.setAttribute(
          outputKey,
          GPXService.convertToString(value, typeInfo.BaseType)
        );
      } else {
        const items = Array.isArray(value) ? value : [value];
        items.forEach((item) => {
          if (typeof item === "object" && item !== null) {
            const child = GPXService.createElementFromObject(
              outputKey,
              item,
              doc
            );
            elem.appendChild(child);
          } else {
            const child = doc.createElementNS(
              GPXService.GpxNamespace,
              outputKey
            );
            child.textContent = GPXService.convertToString(
              item,
              typeInfo.BaseType
            );
            elem.appendChild(child);
          }
        });
      }
    });

    return elem;
  }

  static convertToString(value, baseType) {
    if (value == null) return "";

    switch (baseType) {
      case "decimal":
        return value.toString();
      case "int":
      case "integer":
        return Math.floor(value).toString();
      case "boolean":
        return value.toString().toLowerCase();
      case "dateTime":
        return new Date(value).toISOString();
      default:
        return String(value);
    }
  }

  static xmlToJson(xmlString) {
    const parser = new DOMParser();
    const doc = parser.parseFromString(xmlString, "application/xml");
    return GPXService.elementToObject(doc.documentElement);
  }

  static elementToObject(elem) {
    if (!elem) return null;
    const obj = {};

    // Attributes
    Array.from(elem.attributes).forEach((attr) => {
      if (attr.name === "xmlns" || attr.prefix === "xmlns") return;
      const typeInfo = GPXService.TypeMap[attr.name] || { BaseType: "string" };
      obj[attr.name] = GPXService.convertValue(attr.value, typeInfo.BaseType);
    });

    // Child nodes
    const groups = Array.from(elem.childNodes).reduce((map, child) => {
      if (child.nodeType === Node.TEXT_NODE) return map;
      if (child.localName.startsWith("_")) return map; // Skip child nodes starting with _
      if (!map.has(child.localName)) map.set(child.localName, []);
      map.get(child.localName).push(child);
      return map;
    }, new Map());

    groups.forEach((group, name) => {
      // extendedをextensionsとしてモデルに取り込む（標準準拠）
      //      const modelName = name === "extensions" ? "extended" : name;
      const modelName = name;

      const typeInfo = GPXService.TypeMap[modelName] || { BaseType: "string" };
      const items = group.map((child) => {
        const hasChildren = Array.from(child.childNodes).some(
          (node) => node.nodeType === Node.ELEMENT_NODE
        );
        if (child.attributes.length > 0 || hasChildren) {
          return GPXService.elementToObject(child);
        }
        return GPXService.convertValue(
          child.textContent.trim(),
          typeInfo.BaseType
        );
      });
      obj[modelName] = items.length === 1 ? items[0] : items;
    });

    return obj;
  }

  static convertValue(text, baseType) {
    if (text == null || text === "") return null;

    switch (baseType) {
      case "decimal":
        return parseFloat(text);
      case "int":
      case "integer":
        return parseInt(text, 10);
      case "boolean":
        return text.toLowerCase() === "true";
      case "dateTime":
        return new Date(text);
      default:
        return text;
    }
  }

  // ----------------------------
  // Track Point Operations (for MapSelector)
  // ----------------------------

  getTrkptList() {
    return this.model?.trk?.trkseg?.trkpt ?? [];
  }

  addTrkpt(trkptObj = {}) {
    if (!trkptObj.lat || !trkptObj.lon) {
      throw new Error("lat and lon are required for trkpt");
    }
    // 任意のプロパティを許可（TypeMapに定義されているものに限らず）
    const trkpt = { ...trkptObj };
    const trkseg = this._ensureTrkseg();
    trkseg.trkpt = trkseg.trkpt ?? [];
    trkseg.trkpt.push(trkpt);
    return trkpt;
  }

  removeTrkpt(point) {
    const pts = this.getTrkptList();
    const idx = pts.indexOf(point);
    if (idx >= 0) {
      pts.splice(idx, 1);
    }
  }

  updateTrkpt(index, data) {
    const list = this.getTrkptList();
    const trkpt = list[index];
    if (trkpt) {
      Object.assign(trkpt, data);
    }
  }

  // ----------------------------
  // Internal Utilities
  // ----------------------------

  _normalizeModel(model) {
    if (!model) {
      return {
        version: "1.1",
        creator: "MapSelector",
        trk: { trkseg: { trkpt: [] } },
      };
    }

    model.trk = model.trk ?? {};
    model.trk.trkseg = model.trk.trkseg ?? {};
    model.trk.trkseg.trkpt = Array.isArray(model.trk.trkseg.trkpt)
      ? model.trk.trkseg.trkpt
      : model.trk.trkseg.trkpt
      ? [model.trk.trkseg.trkpt]
      : [];

    return model;
  }

  _ensureTrkseg() {
    this.model.trk = this.model.trk ?? {};
    this.model.trk.trkseg = this.model.trk.trkseg ?? {};
    return this.model.trk.trkseg;
  }
}
