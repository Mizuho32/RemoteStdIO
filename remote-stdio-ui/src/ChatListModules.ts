// import { isMobile } from "react-device-detect";
import axios from "axios"
export default axios

import type { /*AppState, Chat, Message,*/ Stdin } from "./interfaces";
import type { ChatListProps, PrependState, WheeRefreshState } from "./ChatList";
import type { Dispatch, RefObject, SetStateAction } from "react";

export async function onButtonClick(client_id: string) {
    const textarea = document.querySelector<HTMLTextAreaElement>(`#stdin_${client_id}`)
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

export function showClients(props: ChatListProps) {
    const elm: HTMLDivElement|null = document.querySelector('#clientListContainer')
    if (elm) {
        elm.style.width = '100%' // faster
        // elm.style.display = ''
        props.onClientsShown()
    }
}

export function scroll(force: boolean, props: ChatListProps, client_id: string, scrollBottomRef: RefObject<HTMLDivElement | null>) {
    // Not selected, no scroll
    if (props.appState.current_client != client_id) return false

    const scBtm = scrollBottomRef?.current
    if (!force && scBtm && scBtm.parentElement) {
        const msgs = scBtm.parentElement
        const viewScrollHeight = msgs.scrollHeight - msgs.clientHeight;
        const rate = msgs.scrollTop / viewScrollHeight * 100
        // far > 20% from bottom, no scroll
        if (rate < 80) return false
    }
    scrollBottomRef?.current?.scrollIntoView({behavior: 'smooth'});

    return scBtm && scBtm.parentElement
}

export async function onWheel(e: WheelEvent, container: HTMLElement|null, wheelRefSt: WheeRefreshState, setWheelRefSt:  Dispatch<SetStateAction<WheeRefreshState>>, incrementalLoad: ()=>Promise<void>, prependState: RefObject<PrependState>) {
if (!container || container.scrollTop > 0 || wheelRefSt.timeout_disapear_handle !==undefined) return;

if (e.deltaY < 0) {
    if (wheelRefSt.wheelUpCount >= wheelRefSt.fireCount) {
        // triggerRefresh(); // 自作の「引っ張り判定」

        // incremental msgs load
        console.log('Fire!')
        // 1. 現在のスクロール量を記録
        prependState.current = {
            prevScrollHeight: container.scrollHeight,
            prevScrollTop: container.scrollTop,
            prepending: true,
        };
        await incrementalLoad()


        wheelRefSt.timeout_disapear_handle = setTimeout(()=>{
            wheelRefSt.wheelUpCount = 0;
            wheelRefSt.timeout_disapear_handle = undefined
            setWheelRefSt(prev=>({...prev, ...wheelRefSt}))
        }, wheelRefSt.Timeout_disapear)

        setWheelRefSt(prev=>({...prev, ...wheelRefSt}))
        return
    }
    if (wheelRefSt.timeout_handle !== undefined) {
        clearTimeout(wheelRefSt.timeout_handle);
    }

    wheelRefSt.timeout_handle = window.setTimeout(() => {
        wheelRefSt.wheelUpCount = 0;
        setWheelRefSt(wheelRefSt)
    }, wheelRefSt.wheelUpCount > wheelRefSt.showCount ? wheelRefSt.Timeout_slow : wheelRefSt.Timeout); // 連続ホイールの判定タイムアウト
    wheelRefSt.wheelUpCount++;
    setWheelRefSt(prev=>({...prev, ...wheelRefSt}))
}
};

export async function onPull(e: TouchEvent, container: HTMLElement|null, wheelRefSt: WheeRefreshState, setWheelRefSt:  Dispatch<SetStateAction<WheeRefreshState>>, incrementalLoad: ()=>Promise<void>, prependState: RefObject<PrependState>, startY: number|undefined) {
if (!container || container.scrollTop > 0 || wheelRefSt.timeout_disapear_handle !==undefined || startY === undefined) return;

const touch = e.touches[0];
const deltaY = (touch.clientY - startY) / 30
// console.log('move', deltaY)

    if (deltaY > 0) {
        if (wheelRefSt.wheelUpCount >= wheelRefSt.fireCount && prependState.current.prepending == false) {
            // incremental msgs load
            console.log('Fire!')

            // 1. 現在のスクロール量を記録
            prependState.current = {
                prevScrollHeight: container.scrollHeight,
                prevScrollTop: container.scrollTop,
                prepending: true,
            };
            await incrementalLoad()


            wheelRefSt.timeout_disapear_handle = setTimeout(() => {
                wheelRefSt.wheelUpCount = 0;
                wheelRefSt.timeout_disapear_handle = undefined
                setWheelRefSt(prev => ({ ...prev, ...wheelRefSt }))
            }, wheelRefSt.Timeout_disapear)

            setWheelRefSt(prev => ({ ...prev, ...wheelRefSt }))
            return
        }

        wheelRefSt.wheelUpCount = deltaY
        setWheelRefSt(prev=>({...prev, ...wheelRefSt}))
    }
}
