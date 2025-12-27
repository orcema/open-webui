import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

import { viteStaticCopy } from 'vite-plugin-static-copy';

export default defineConfig({
	plugins: [
		sveltekit(),
		viteStaticCopy({
			targets: [
				{
					src: 'node_modules/onnxruntime-web/dist/*.jsep.*',

					dest: 'wasm'
				}
			]
		})
	],
	define: {
		APP_VERSION: JSON.stringify(process.env.npm_package_version),
		APP_BUILD_HASH: JSON.stringify(process.env.APP_BUILD_HASH || 'dev-build'),
		// Expose DOCKER env var to frontend for Docker dev mode detection
		'import.meta.env.DOCKER': JSON.stringify(process.env.DOCKER || 'false')
	},
	build: {
		sourcemap: true
	},
	worker: {
		format: 'es'
	},
	esbuild: {
		pure: process.env.ENV === 'dev' ? [] : ['console.log', 'console.debug', 'console.error']
	},
	server: {
		// Enable source maps in dev mode for debugging
		sourcemapIgnoreList: false,
		// Proxy API requests to backend when running in Docker dev mode
		proxy: process.env.DOCKER === 'true' ? {
			'/api': {
				target: 'http://localhost:8080',
				changeOrigin: true,
				secure: false
			},
			'/ollama': {
				target: 'http://localhost:8080',
				changeOrigin: true,
				secure: false
			},
			'/openai': {
				target: 'http://localhost:8080',
				changeOrigin: true,
				secure: false
			},
			'/static': {
				target: 'http://localhost:8080',
				changeOrigin: true,
				secure: false
			},
			'/health': {
				target: 'http://localhost:8080',
				changeOrigin: true,
				secure: false
			},
			'/ws': {
				target: 'http://localhost:8080',
				changeOrigin: true,
				secure: false,
				ws: true // Enable WebSocket proxying
			}
		} : undefined
	}
});
