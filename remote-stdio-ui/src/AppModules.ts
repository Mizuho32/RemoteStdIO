// import { isMobile } from "react-device-detect";
import axios from "axios"
export default axios

import type { AppState, Chat, Message, Stdin } from "./interfaces";
import * as utils from './utils'

export async function onClientOpen(client_id: string, appState: AppState, setAppState: React.Dispatch<React.SetStateAction<AppState>>) {
    const chats = appState.chats
    const chat = chats[client_id] || {}
    const msg_is_empty = !chat?.msgs || chat?.msgs.length === 0  //Object.keys(chat).length  === 0
    let newState: AppState = {...appState, current_client: client_id}

    if (msg_is_empty) { // only once
        const result = await axios.get<Message[]>(`/api/stdout?client_id=${client_id}`)
        if (result.status == 200) {
            const newmsgs: Message[] = result.data.map(msg => ({...msg, datetime: new Date(msg.datetime)}))
            newState = {...newState, chats: {...chats, [client_id]: {...chat,  msgs: [...(chat.msgs||[]), ...newmsgs]}}}
        }
    }
    setAppState(newState)
    /*prev => {
        const chats = prev.chats
        const chat = chats[client_id] || {}
        if (chat_is_empty) { // only once
            const newmsgs: Message[] = result.data.map(msg => ({...msg, datetime: new Date(msg.datetime)}))
            const newone: AppState = {...prev, current_client: client_id, chats: {...chats, [client_id]: {...chat,  msgs: [...(chat.msgs||[]), ...newmsgs]}}}
            // console.log(newone)
            return newone
        } else 
            return {...prev, current_client: client_id}
    })
    */
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