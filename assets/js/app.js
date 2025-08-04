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
    this.el.addEventListener('click', (e) => {
      // Prevent the click from bubbling up to parent elements (like drawer backdrop)
      e.stopPropagation()
      
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

// Mobile Drawer Hook with swipe gestures
Hooks.MobileDrawer = {
  mounted() {
    this.startY = 0
    this.currentY = 0
    this.isDragging = false
    this.threshold = 50 // minimum swipe distance
    
    // Touch event listeners for swipe gestures
    this.el.addEventListener('touchstart', (e) => {
      this.startY = e.touches[0].clientY
      this.isDragging = true
    }, { passive: false })
    
    this.el.addEventListener('touchmove', (e) => {
      if (!this.isDragging) return
      
      this.currentY = e.touches[0].clientY
      const deltaY = this.currentY - this.startY
      
      // Only allow downward swipes (positive deltaY)
      if (deltaY > 0) {
        // Prevent browser's pull-to-refresh when swiping down on drawer
        e.preventDefault()
        
        // Provide visual feedback during drag
        const progress = Math.min(deltaY / 200, 1)
        this.el.style.transform = `translateY(${deltaY * 0.5}px)`
        this.el.style.opacity = `${1 - progress * 0.3}`
      }
    }, { passive: false })
    
    this.el.addEventListener('touchend', (e) => {
      if (!this.isDragging) return
      
      const deltaY = this.currentY - this.startY
      
      // Reset transform
      this.el.style.transform = ''
      this.el.style.opacity = ''
      
      // Close drawer if swiped down enough
      if (deltaY > this.threshold) {
        this.pushEvent('close_drawer')
      }
      
      this.isDragging = false
    }, { passive: false })
  }
}

// Viewport Detection Hook - handles responsive layout switching
Hooks.ViewportDetector = {
  mounted() {
    this.updateViewport()
    this.saveCurrentFilters()
    
    // Add resize listener for responsive behavior
    this.resizeHandler = () => {
      this.updateViewport()
    }
    
    window.addEventListener('resize', this.resizeHandler)
  },
  
  updated() {
    this.saveCurrentFilters()
  },
  
  destroyed() {
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
    }
  },
  
  updateViewport() {
    const viewport = window.innerWidth >= 1024 ? 'desktop' : 'mobile'
    this.pushEvent('set_viewport', { viewport: viewport })
  },
  
  saveCurrentFilters() {
    // Only save filters if we're on the home page
    if (window.location.pathname !== '/' && window.location.pathname !== '') {
      return
    }
    
    // Extract filter state from current URL
    const urlParams = new URLSearchParams(window.location.search)
    const filterState = {
      tags: urlParams.get('tags') || '',
      series: urlParams.get('series') || '',
      search: urlParams.get('search') || '',
      timestamp: Date.now()
    }
    
    // Only save if there are actual filters applied
    if (filterState.tags || filterState.series || filterState.search) {
      sessionStorage.setItem('blog_filter_state', JSON.stringify(filterState))
    } else {
      // Clear saved state if no filters
      sessionStorage.removeItem('blog_filter_state')
    }
  }
}

// Mobile Safari Browser Controls Fix - ensures proper document scrolling
Hooks.MobileScrollFix = {
  mounted() {
    // Only apply on mobile devices
    if (window.innerWidth >= 1024) return
  }
}


// Back Button Hook - navigates back with preserved filter state
Hooks.BackButton = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault()
      
      // Try to get saved filter state
      const savedState = sessionStorage.getItem('blog_filter_state')
      
      if (savedState) {
        try {
          const filterState = JSON.parse(savedState)
          
          // Check if state is not too old (1 hour)
          const oneHour = 60 * 60 * 1000
          if (Date.now() - filterState.timestamp < oneHour) {
            // Reconstruct filtered home URL
            const params = []
            if (filterState.tags) params.push(['tags', filterState.tags])
            if (filterState.series) params.push(['series', filterState.series])
            if (filterState.search) params.push(['search', filterState.search])
            
            const homeUrl = params.length > 0 ? '/?' + new URLSearchParams(params).toString() : '/'
            window.location.href = homeUrl
            return
          }
        } catch (e) {
          // Silently fall back to home page if parsing fails
        }
      }
      
      // Fallback to plain home page
      window.location.href = '/'
    })
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

