// js/gpx-service.js

export default class GPXService {
  // PowerShell TypeMap 相当
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
  };

  static GpxNamespace = "http://www.topografix.com/GPX/1/1";

  constructor() {
    this.doc = document.implementation.createDocument(
      GPXService.GpxNamespace,
      "gpx",
      null
    );
    this.model = {
      trk: {
        trkseg: {
          trkpt: [],
        },
      },
    };
  }

  // ----------------------------
  // 公開 API（モデル操作）
  // ----------------------------

  setModel(model) {
    this.model = this._normalizeModel(model);
  }

  getModel() {
    return this.model;
  }

  loadFromXml(xmlString) {
    const json = GPXService.xmlToJson(xmlString);
    this.model = this._normalizeModel(json);
  }

  toXml() {
    if (!this.model) return "";
    return this.jsonToXml(this.model);
  }

  // ----------------------------
  // trkpt 操作 API（MapSelector 用）
  // ----------------------------

  getTrkptList() {
    const trk = this.model?.trk;
    if (!trk) return [];

    const seg = trk.trkseg;
    if (!seg) return [];

    const pts = seg.trkpt;
    if (!pts) return [];

    return Array.isArray(pts) ? pts : [pts];
  }

  addTrkpt(lat, lon, name = "", desc = "") {
    const tp = { lat, lon, name, desc };

    const trk = (this.model.trk = this.model.trk || {});
    const seg = (trk.trkseg = trk.trkseg || {});
    const list = (seg.trkpt = seg.trkpt || []);

    if (Array.isArray(list)) {
      list.push(tp);
    } else {
      seg.trkpt = [list, tp];
    }

    return tp;
  }

  removeTrkpt(index) {
    const list = this.getTrkptList();
    if (!Array.isArray(list)) return;

    if (index >= 0 && index < list.length) {
      list.splice(index, 1);
    }
  }

  updateTrkpt(index, data) {
    const list = this.getTrkptList();
    if (!Array.isArray(list)) return;

    const tp = list[index];
    if (!tp) return;

    Object.assign(tp, data);
  }

  // ----------------------------
  // JSON → XML
  // ----------------------------

  createElementFromObject(name, obj) {
    const elem = this.doc.createElementNS(GPXService.GpxNamespace, name);
    if (!obj) return elem;

    const pairs = Object.entries(obj);

    for (const [key, value] of pairs) {
      const typeInfo = GPXService.TypeMap[key] || {
        BaseType: "string",
        IsAttribute: false,
      };

      if (typeInfo.IsAttribute) {
        elem.setAttribute(
          key,
          GPXService.convertToString(value, typeInfo.BaseType)
        );
      } else {
        const items = Array.isArray(value) ? value : [value];

        for (const item of items) {
          if (typeof item === "object" && item !== null) {
            const child = this.createElementFromObject(key, item);
            elem.appendChild(child);
          } else {
            const child = this.doc.createElementNS(
              GPXService.GpxNamespace,
              key
            );
            child.textContent = GPXService.convertToString(
              item,
              typeInfo.BaseType
            );
            elem.appendChild(child);
          }
        }
      }
    }

    return elem;
  }

  static convertToString(value, baseType) {
    if (value === null || value === undefined) return "";

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

  jsonToXml(json) {
    const root = this.createElementFromObject("gpx", json);
    this.doc.replaceChild(root, this.doc.documentElement);
    return new XMLSerializer().serializeToString(this.doc);
  }

  // ----------------------------
  // XML → JSON
  // ----------------------------

  static elementToObject(elem) {
    if (!elem) return null;
    const obj = {};

    // Attributes
    for (const attr of elem.attributes) {
      if (attr.name === "xmlns" || attr.prefix === "xmlns") continue;

      const typeInfo = GPXService.TypeMap[attr.name] || { BaseType: "string" };
      obj[attr.name] = GPXService.convertValue(attr.value, typeInfo.BaseType);
    }

    // Group child nodes
    const groups = new Map();
    for (const child of elem.childNodes) {
      if (child.nodeType === Node.TEXT_NODE) continue;
      if (!groups.has(child.localName)) {
        groups.set(child.localName, []);
      }
      groups.get(child.localName).push(child);
    }

    for (const [name, group] of groups) {
      const typeInfo = GPXService.TypeMap[name] || { BaseType: "string" };
      const items = group.map((child) => {
        const hasElementChildren = Array.from(child.childNodes).some(
          (node) => node.nodeType === Node.ELEMENT_NODE
        );
        if (child.attributes.length > 0 || hasElementChildren) {
          return GPXService.elementToObject(child);
        } else {
          return GPXService.convertValue(
            child.textContent.trim(),
            typeInfo.BaseType
          );
        }
      });
      obj[name] = items.length === 1 ? items[0] : items;
    }

    return obj;
  }

  static convertValue(text, baseType) {
    if (text === null || text === "") return null;

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

  static xmlToJson(xmlString) {
    const parser = new DOMParser();
    const doc = parser.parseFromString(xmlString, "application/xml");
    return GPXService.elementToObject(doc.documentElement);
  }

  // ----------------------------
  // 内部：JSON 標準化
  // ----------------------------
  _normalizeModel(json) {
    if (!json) {
      return {
        version: "1.1",
        creator: "MapSelector",
        trk: { trkseg: { trkpt: [] } },
      };
    }

    // trk
    json.trk = json.trk || {};
    json.trk.trkseg = json.trk.trkseg || {};
    let pts = json.trk.trkseg.trkpt;

    if (!pts) {
      json.trk.trkseg.trkpt = [];
    } else if (!Array.isArray(pts)) {
      json.trk.trkseg.trkpt = [pts];
    }

    return json;
  }
}
