const esbuild = require('esbuild')
const sveltePlugin = require('esbuild-svelte')

const isDev = process.argv.includes('--watch')

const config = {
  entryPoints: ['js/app.js'],
  bundle: true,
  target: 'es2017',
  outfile: '../priv/static/assets/app.js',
  external: ['/fonts/*', '/images/*'],
  plugins: [
    sveltePlugin({
      compilerOptions: {
        dev: isDev,
        css: 'injected'
      }
    })
  ],
  loader: {
    '.png': 'file',
    '.jpg': 'file',
    '.jpeg': 'file',
    '.gif': 'file',
    '.svg': 'file'
  },
  sourcemap: isDev,
  minify: !isDev
}

if (isDev) {
  esbuild.context(config).then(ctx => {
    ctx.watch()
    console.log('Watching for changes...')
  })
} else {
  esbuild.build(config).catch(() => process.exit(1))
}