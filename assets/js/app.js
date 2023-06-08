// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let map_markers = {};
let map = L.map('leaflet-map');

const iconSize = 50;

const markerPosition = (marker_element) => {
  return [
    marker_element.getAttribute('data-latitude'),
    marker_element.getAttribute('data-longitude'),
  ]
}

const markerIcon = (marker_element) => {
  let type = marker_element.getAttribute('data-type'),
      metadata = JSON.parse(marker_element.getAttribute('data-metadata')),
      emoji;

  switch (type) {
    case 'driver':
      emoji = metadata.ready_for_passengers  ? "🚙" : "🚗";
      break;

    case 'passenger':
      emoji = metadata.ride_requested ? "🕺" : "🧍";
      break;

    case 'ride':
      emoji = "🚕";
  }

  return L.divIcon({
    iconSize: [iconSize, iconSize],
    iconAnchor: [iconSize / 2, iconSize + 9],
    html: `<span style="display: inline-block; line-height: normal; vertical-align: middle">${emoji}</span>`
  })
}

const newMarker = (marker_element) => {
  return L.marker(
    markerPosition(marker_element),
    {icon: markerIcon(marker_element)}
  )
}

// const update_map = (el) => {
//   let marker_elements = el.getElementsByClassName('marker')

//   Array.from(marker_elements).forEach((marker_element) => {
//     let id = marker_element.getAttribute('id');

//     console.log({id})
//     let position = markerPosition(marker_element);

//     if (!map_markers[id]) {
//       map_markers[id] = newMarker(marker_element);
//       map_markers[id].addTo(map)
//     } else {
//       map_markers[id].setIcon(markerIcon(marker_element));
//       map_markers[id].setLatLng(position);
//     }
//   })
// }

let Hooks = {}

Hooks.Map = {
  mounted() {
    // console.log('map mounted')
    let el = this.el;

    // console.log('show_map')

    let latitude = el.getAttribute('data-latitude')
    let longitude = el.getAttribute('data-longitude')
    let zoom = el.getAttribute('data-zoom')

    // let map_el = el.getElementById('leaflet-map')

    // if (map_el) {
    //     // reset the map div
    //     map_el._leaflet_id = null;
    // }

    // if (map_el && latitude && longitude) {
    if (latitude && longitude) {
        latitude = parseFloat(latitude)
        longitude = parseFloat(longitude)
      // console.log('created map')
        map.setView([latitude, longitude], zoom);

        L.tileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            subdomains: ['a', 'b', 'c']
        }).addTo(map);
    }
  },
  // updated() {
  //   update_map(this.el)
  // }
}

Hooks.Marker = {
  mounted() {
    // console.log('marker mounted')
    let marker_element = this.el;
    let id = marker_element.getAttribute('id');

    // console.log({marker_element})
    map_markers[id] = newMarker(marker_element);
    // console.log('adding to map')
    map_markers[id].addTo(map);

  },
  updated() {
    // console.log('marker updated')
    let marker_element = this.el;
    let id = marker_element.getAttribute('id');

    map_markers[id].setIcon(markerIcon(marker_element));
    // console.log({position: markerPosition(marker_element)})
    map_markers[id].setLatLng(markerPosition(marker_element));
  },
  destroyed() {
    // console.log('marker destroyed')
    let marker_element = this.el;
    let id = marker_element.getAttribute('id');

    map_markers[id].remove()
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})


// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.delayedShow(200))
window.addEventListener("phx:page-loading-stop", info => topbar.hide())


// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

