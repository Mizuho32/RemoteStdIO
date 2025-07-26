// import { isMobile } from "react-device-detect";
import axios from "axios"
export default axios

import type { AppState, Chat, Message, Stdin } from "./interfaces";
import * as utils from './utils'
import type { RefObject } from "react";

export async function getMsgs(client_id: string, max_count?: number, direction_past?: boolean, _id?: string) {
    let params: any = {client_id: client_id}
    if (max_count      !== undefined) params['max_count'] = max_count
    if (direction_past !== undefined) params['direction_past'] = direction_past ? 1 : 0
    if (_id            !== undefined) params['_id'] = _id

    const result = await axios.get<Message[]>(`/api/stdout`, {params: params})
    if (result.status == 200) {
        const newmsgs: Message[] = result.data.map(msg => ({ ...msg, datetime: new Date(msg.datetime) }))
        return newmsgs
    }
    return []
}

export async function incrementalLoad(client_id: string, size: number, to_past: boolean, appStateRef: RefObject<AppState>, setAppState: React.Dispatch<React.SetStateAction<AppState>>) {
    const appState = appStateRef.current
    if (!appState) return

    const msgs = appState?.chats[client_id]?.msgs
    if (msgs) {
        const _id = msgs[0]._id
        const increMsgs = await getMsgs(client_id, size, to_past, _id)
        // console.log('incMsgs', client_id, _id, increMsgs)

        setAppState(prev => {
            const chats = prev.chats
            const chat = chats[client_id] || {}
            const newone: AppState = { ...prev, chats: { ...chats, [client_id]: { ...chat, msgs: [...increMsgs, ...(chat.msgs || [])] } } }
            return newone
        })
    }
}

export async function onClientOpen(client_id: string, appStateRef: RefObject<AppState>, setAppState: React.Dispatch<React.SetStateAction<AppState>>) {
    const appState = appStateRef.current
    const chats = appState.chats
    const chat = chats[client_id] || {}
    const msg_is_empty = !chat?.msgs || chat?.msgs.length === 0  //Object.keys(chat).length  === 0
    let newmsgs: Message[] = []
    localStorage.setItem('rmtstdio.current_client', client_id)

    if (msg_is_empty) { // only once
        newmsgs = await getMsgs(client_id)
    }
    setAppState(prev => {
        const chats = prev.chats
        const chat = chats[client_id] || {}
        return {...prev, chats: {...chats, [client_id]: {...chat,  msgs: [...(chat.msgs||[]), ...newmsgs]}}, current_client: client_id}
    })
}

export function onClientsHidden(hidden: boolean, appState: AppState, setAppState: React.Dispatch<React.SetStateAction<AppState>>) {
    setAppState({...appState, clients_hidden: hidden})
}

export function startWebSocket(setAppState: React.Dispatch<React.SetStateAction<AppState>>) {
    // send
    let socket = new WebSocket(`ws://${location.host}/api/websocket/front`);
    socket.onopen = function () {
        // socket.send(
        //     JSON.stringify({ artist: artist, tags: csvData, filename: filename, key: "lock" }));
    };

    // let timeout_id = setTimeout(() => {
    //     socket.close();
    //     alert("アップロードがタイムアウトしました");
    // }, 5 * 1000);

    socket.onmessage = function (event) {
        // clearTimeout(timeout_id);

        const ws_data = JSON.parse(event.data)
        if (ws_data?.type == 'msg') {
            let msg: Message = ws_data.data
            msg.datetime = new Date(msg.datetime)
            msg.client_id
            setAppState(prev => {
                const chats = prev.chats
                const chat = chats[msg.client_id] || {}
                const newone: AppState = { ...prev, chats: { ...chats, [msg.client_id]: { ...chat, msgs: [...(chat.msgs || []), msg] } } }
                // console.log(newone)
                return newone
            })
        } else if (ws_data?.type == 'stdin') {
            let data: Stdin = ws_data.data
            setAppState(prev => {
                const client_id = data.client_id
                if (client_id) {
                    const chat = prev.chats[client_id] || {}
                    const chat_new: Chat = { ...chat, stdin_enabled: data.status == 'open' }
                    console.log('std ws', data, "enabled", chat_new.stdin_enabled)
                    return { ...prev, chats: { [client_id]: chat_new } }
                } else {
                    return prev
                }
            })
        } else {
            console.log('WS Error: ', ws_data)
        }
    };

    socket.onclose = function() {
        (async function(){
            console.log('WS closed. retry after 30s')
            await utils.sleep(30 * 1000)
            startWebSocket(setAppState)
        })()
    }

}