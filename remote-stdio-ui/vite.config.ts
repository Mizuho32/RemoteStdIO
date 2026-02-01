import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const port = process.env['BACKEND_PORT_DBG'];
const host = `${process.env['BACKEND_HOST_DBG']}:${port}`;

// https://vite.dev/config/
export default defineConfig({
	plugins: [react()],
	server: {
		host: '0.0.0.0', // 任意のIPアドレスからの接続を許可
		//port: 3000 // 使用したいポート番号を指定
		proxy: {
			'/api': {
				target: `http://${host}`, // APIサーバーのURL
				changeOrigin: true,
				rewrite: (path) => path.replace(/^\/api/, '') // /apiを除去する場合
			},
			// WebSocketのプロキシ設定
			'/api/websocket': {
				target: `ws://${host}/websocket`,
				ws: true,
				changeOrigin: true,
				rewrite: (path) => path.replace(/^\/api\/websocket/, '')
			}
		}
	}

})
