// map-initializer.js

export default class MapInitializer {
    constructor(selector) {
        this.selector = selector;
    }

    initMap() {
        this.selector.map = L.map(this.selector.mapId).setView([this.selector.initialView[0], this.selector.initialView[1]], this.selector.initialView[2]);

        L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "© OpenStreetMap contributors",
            maxZoom: 19
        }).addTo(this.selector.map);

        // Geocoder（住所検索）
        if (L.Control && L.Control.geocoder) {
            L.Control.geocoder({ defaultMarkGeocode: false })
                .on("markgeocode", (e) => { this.selector.map.setView(e.geocode.center, 16); })
                .addTo(this.selector.map);
        }

        // distortableCollection を作成
        try {
            if (typeof L.distortableCollection === 'function') {
                this.selector.imgGroup = L.distortableCollection().addTo(this.selector.map);
            } else {
                console.warn('L.distortableCollection is not available.');
                this.selector.imgGroup = { eachLayer: () => {}, addLayer: () => {}, removeLayer: () => {} };
            }
        } catch (e) {
            console.warn('distortableCollection init failed', e);
            this.selector.imgGroup = { eachLayer: () => {}, addLayer: () => {}, removeLayer: () => {} };
        }

        this.selector.map.on("click", (e) => {
            if (this.selector.isLocked) {
                const lat = e.latlng.lat.toFixed(6);
                const lng = e.latlng.lng.toFixed(6);
                document.getElementById(this.selector.controls.coordsId).innerText = `${lat}, ${lng}`;

                const info = { lat: e.latlng.lat, lon: e.latlng.lng, name: "", desc: "", extended: {} };
                this.selector.markerHandler.addPoint(info);

                const newMarker = this.selector.markerHandler.markers[this.selector.markerHandler.markers.length - 1];
                this.selector.fetchAddressAsync(info, newMarker);
            }
        });
    }
}