// api-utils.js

export function fetchAddressAsync(point, marker, markerHandler) {
    const seq = ++markerHandler.requestSeq;
    point._reqSeq = seq;

    const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.lat}&lon=${point.lon}&zoom=18&addressdetails=1`;

    fetch(url)
        .then(res => res.json())
        .then(data => {
            if (point._reqSeq !== seq) return;
            if (!markerHandler.markers.includes(marker)) return;

            point.name = data.name || "";
            point.desc = data.display_name || "";
            point.extended = data.address || {};

            try {
                marker.bindPopup(point.name || point.desc).openPopup();
            } catch (e) { /* ignore */ }
            markerHandler.selector.uiManager.updateListUI();
        })
        .catch(e => console.log("Address fetch error", e));
}