// import { isMobile } from "react-device-detect";
import axios from "axios"
export default axios

import type { AppState, Chat, Message, Stdin } from "./interfaces";

export async function onButtonClick(client_id: string) {
    const textarea = document.querySelector<HTMLTextAreaElement>('#stdin')
    const textBody = textarea?.value
    if (textBody) {
        const json: Stdin = {status: 'input', client_id: client_id, message: textBody}
        await axios.post('/api/stdin', json, {
            params: {client_id: client_id}, // ← これはURLのクエリパラメータ
            headers: {
                // 'Content-Type': 'text/plain', // 必要に応じて変更（例: application/json）
                'Content-Type': 'application/json',
            },
        })
        textarea.value = ''
    }
}