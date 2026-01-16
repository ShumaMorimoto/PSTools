/**
 * MunicipalityLogic.js
 * �����Ǝ����̓���i���񏈗��j��S�����郍�W�b�N���W���[��
 */

let muniCache = null;
let muniMasterList = [];

// �}�X�^�f�[�^�̃��[�h
// ���p�X�̓v���W�F�N�g�\���ɍ��킹�ĕύX���Ă������� ("./municipalities.json" ��)
const JSON_PATH = "./../../municipalities.json";

export async function loadMunicipalities() {
    if (muniCache) return;
    try {
        const res = await fetch(JSON_PATH);
        const json = await res.json();
        const rawData = Array.isArray(json) ? json : (json.municipalities || []);
        muniCache = rawData;
        
        // ������ƍ��p�ɒ������Ń\�[�g
        muniMasterList = [...rawData].sort((a, b) => {
            const lenA = (a.prefecture + a.municipality).length;
            const lenB = (b.prefecture + b.municipality).length;
            return lenB - lenA;
        });
    } catch (e) {
        console.error("Master Load Error:", e);
        muniCache = [];
    }
}

// 1����Feature�ɑ΂��Ď����̂���肷��
async function identifyMunicipality(feature) {
    const props = feature.properties;
    const geometry = feature.geometry;
    
    let result = {
        lat: geometry.coordinates[1],
        lon: geometry.coordinates[0],
        title: props.title,
        matchedMuni: null,
        matchType: 'none' // code, string, geo, none
    };

    if (!muniMasterList.length) return result;

    // Pattern 1: AddressCode
    const ac = props.AddressCode || "";
    if (ac.length >= 5) {
        const m = muniCache.find(x => x.muniCd5 === ac.substring(0, 5));
        if (m) {
            result.matchedMuni = m;
            result.matchType = 'code';
            return result;
        }
    }

    // Pattern 2: String Match
    if (props.title) {
        const t = props.title.replace(/\s+/g, "");
        for (const m of muniMasterList) {
            const ms = (m.prefecture + m.municipality).replace(/\s+/g, "");
            if (t.startsWith(ms)) {
                result.matchedMuni = m;
                result.matchType = 'string';
                return result;
            }
        }
    }

    // Pattern 3: Reverse Geocoding
    try {
        const u = `https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=${result.lat}&lon=${result.lon}`;
        const res = await fetch(u);
        const json = await res.json();
        if (json && json.results && json.results.muniCd) {
            const m = muniCache.find(x => x.muniCd5 === json.results.muniCd);
            if (m) {
                result.matchedMuni = m;
                result.matchType = 'geo';
            }
        }
    } catch (e) { /* ignore error */ }

    return result;
}

// �O������Ă΂�郁�C�������֐�
export async function searchGSI(query) {
    await loadMunicipalities();
    
    const url = `https://msearch.gsi.go.jp/address-search/AddressSearch?q=${encodeURIComponent(query)}`;
    const res = await fetch(url);
    const features = await res.json();

    // ���񏈗����s
    const tasks = features.map(f => identifyMunicipality(f));
    const results = await Promise.all(tasks);

    // Leaflet�R���|�[�l���g�p�ɐ��`���ĕԂ�
    return results.map(r => {
        let desc = "";
        let code = "";
        
        if (r.matchedMuni) {
            desc = `${r.matchedMuni.prefecture}${r.matchedMuni.municipality}`;
            code = r.matchedMuni.muniCd5;
        }

        return {
            lat: r.lat,
            lon: r.lon,
            name: r.title,
            desc: desc,
            extensions: {
                keyword: query,
                addressCode: code,
                matchType: r.matchType
            },
            source: "web"
        };
    });
}

