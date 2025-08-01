// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "./svelte/**/*.svelte",
    "../lib/blog_web.ex",
    "../lib/blog_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        // Theme-aware Catppuccin colors using CSS custom properties
        rosewater: "rgb(var(--color-rosewater))",
        flamingo: "rgb(var(--color-flamingo))",
        pink: "rgb(var(--color-pink))",
        mauve: "rgb(var(--color-mauve))",
        red: "rgb(var(--color-red))",
        maroon: "rgb(var(--color-maroon))",
        green: "rgb(var(--color-green))",
        teal: "rgb(var(--color-teal))",
        sky: "rgb(var(--color-sky))",
        sapphire: "rgb(var(--color-sapphire))",
        blue: "rgb(var(--color-blue))",
        lavender: "rgb(var(--color-lavender))",
        base: "rgb(var(--color-base))",
        mantle: "rgb(var(--color-mantle))",
        crust: "rgb(var(--color-crust))",
        surface0: "rgb(var(--color-surface0))",
        surface1: "rgb(var(--color-surface1))",
        surface2: "rgb(var(--color-surface2))",
        overlay0: "rgb(var(--color-overlay0))",
        overlay1: "rgb(var(--color-overlay1))",
        overlay2: "rgb(var(--color-overlay2))",
        subtext0: "rgb(var(--color-subtext0))",
        subtext1: "rgb(var(--color-subtext1))",
        text: "rgb(var(--color-text))",
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
        })
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, {values})
    })
  ]
}
