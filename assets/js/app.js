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

// Hooks
let Hooks = {}

// Theme Toggle Hook
Hooks.ThemeToggle = {
  mounted() {
    // Initialize theme from localStorage or default to dark
    const savedTheme = localStorage.getItem('theme') || 'dark'
    this.setTheme(savedTheme)
    
    // Add click event listener
    this.el.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'dark'
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
      this.setTheme(newTheme)
    })
  },
  
  setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('theme', theme)
    
    // Update icon visibility based on theme
    const sunIcon = this.el.querySelector('.sun-icon')
    const moonIcon = this.el.querySelector('.moon-icon')
    
    if (theme === 'light') {
      if (sunIcon) sunIcon.classList.add('hidden')
      if (moonIcon) moonIcon.classList.remove('hidden')
      this.el.setAttribute('aria-label', 'Switch to dark theme')
      this.el.setAttribute('title', 'Switch to dark theme')
    } else {
      if (sunIcon) sunIcon.classList.remove('hidden')
      if (moonIcon) moonIcon.classList.add('hidden')
      this.el.setAttribute('aria-label', 'Switch to light theme')
      this.el.setAttribute('title', 'Switch to light theme')
    }
  }
}

// Infinite Scroll Hook
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

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

