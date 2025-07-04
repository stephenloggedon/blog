// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

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

// Infinite Scroll Hook
let Hooks = {}
Hooks.InfiniteScroll = {
  mounted() {
    this.pending = false
    this.observer = new IntersectionObserver(entries => {
      const target = entries[0]
      if (target.isIntersecting && !this.pending) {
        this.pending = true
        this.pushEvent("load_more", {}, () => {
          this.pending = false
        })
      }
    }, {
      root: this.el,
      rootMargin: "100px"
    })
    
    // Observe the loading indicator
    const loadingIndicator = document.getElementById("loading-indicator")
    if (loadingIndicator) {
      this.observer.observe(loadingIndicator)
    }
  },
  
  updated() {
    // Re-observe when content updates
    const loadingIndicator = document.getElementById("loading-indicator")
    if (loadingIndicator && !this.pending) {
      this.observer.observe(loadingIndicator)
    }
  },
  
  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Enable debug mode to see what's happening
liveSocket.enableDebug()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

console.log("LiveSocket initialized and connected")

