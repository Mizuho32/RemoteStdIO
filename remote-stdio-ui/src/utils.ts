// import { isMobile } from "react-device-detect";
import axios from "axios"
export default axios
// import { nanoid } from "nanoid";

// import { APIReturn, AppState } from "./interfaces";
// import * as songUtils from './songUtils'

export function sleep(time: number) {
    return new Promise((resolve) => setTimeout(resolve, time));//timeはミリ秒
}


// export async function initSession(appState: AppState, artist: string, filename: string|null = "", audioEl: HTMLAudioElement) {

//     let sessionID: string = appState.cookies.sessionID

//     if (!sessionID) {
//         sessionID = nanoid()
//     }
//     const expire = new Date();
//     expire.setMonth(expire.getMonth() + 6);
//     const cookieDate = new Date(expire)
//     appState.setCookie("sessionID", sessionID, { expires: cookieDate, path: '/' })

//     appState.audioEl = audioEl

//     return await startSession(appState, artist, filename)
// }

// export async function startSession(appState: AppState, artist: string, filename: string|null = "") {
//     let ret = true
//     if (artist) {
//         // FIXME?
//         appState.artist = artist
//         appState.setArtist(artist)
//     } else {
//         artist = appState.artist
//     }
//     let param = ""

//     if (filename) {

//         // release lock
//         if (appState.filename != filename) {
//             await lock(appState.artist, appState.filename, appState.cookies.sessionID, false)
//         }

//         // get lock
//         const status = await lock(appState.artist, filename, appState.cookies.sessionID, true)
//         if (status) {
//             appState.filename = filename
//             appState.setFilename(filename)

//             await songUtils.fetchDetections(appState)
//             param = `?artist=${artist}&filename=${filename}`

//         } else {
//             ret = false
//         }

//     }

//     await songUtils.fetchStreams(appState)
//     if (param && appState.audioEl) appState.audioEl.src = `/audio${param}`
//     return ret
// }

// export async function endSession(appState: AppState) {
//     const filename = appState.filename

//     if (filename) {
//         let released = false
//         // release lock
//         released = await lock(appState.artist, appState.filename, appState.cookies.sessionID, false)
        
//         if (released) {
//             alert("ロック解除しました")
//         } else {
//             alert("ロック解除失敗。既に解除されている?")
//         }
//     }

//     await songUtils.fetchStreams(appState)
//     if (appState.audioEl) {
//         appState.audioEl.src = ""
//     }

//     appState.filename = ""
//     appState.setFilename("")
//     appState.songList = []
//     appState.setSongList([])
// }

// export async function lock(artist: string, filename: string, sid: string, get: boolean) {
//     if (!artist || !filename || !sid) return false

//     let param = `?artist=${artist}&filename=${filename}`
//     if (get) {
//         param += `&lock=${sid}`
//     } else { // release
//         param += `&unlock=${sid}`
//     }

//     try {
//         const results = await axios.get<APIReturn>(`/api/lock${param}`);
//         if (results.status === 200) {
//             console.log(get ? "lock" : "unlock", results.data)
//             console.log("lock get", results.data)
//             return results.data.status
//         }
//     } catch (error) {
//         alert(`Error fetching data\n${error}`);
//     }

//     return false
// }

// export function unlockWhenClose(appState: AppState) {

//     const artist = appState.artist
//     const filename = appState.filename
//     const sid = appState.cookies.sessionID

//     if (!artist || !filename || !sid) return

//     let socket = new WebSocket(`ws://${location.host}/api/websocket`);
//     socket.onopen = function () {
//         socket.send(
//             JSON.stringify({ artist: artist, filename: filename, unlock: sid }))
//     }

//     /*let timeout_id = setTimeout(() => {
//         socket.close();
//         alert("アップロードがタイムアウトしました");
//     }, 5 * 1000)

//     socket.onmessage = function (event) {
//         clearTimeout(timeout_id);

//         let num = parseInt(event.data);
//         if (num == csvData.length) {
//             alert("アップロード完了");

//             // unlock
//             //onclose();

//         } else {
//             alert(`Error: ${event.data}`);
//         }

//         socket.close();
//     }*/
// }

// // Search
// export function search(appState:AppState, word: string) {
//   console.log(`search got "${word}"`);

//   if (word !== "") {
//     let socket = new WebSocket(`ws://${location.host}/api/websocket`);

//     socket.onopen = function() {
//       socket.send(JSON.stringify({search: word}));
//     };

//     socket.onmessage = function(event) {
//         let div = document.querySelector('#searchContent')
//         if (div) {
//             div.innerHTML = event.data;
//             const search_main = div.querySelector("#main")
//             search_main?.setAttribute("id", "search_main")

//             div.querySelectorAll("a").forEach(a => {
//                 a.removeAttribute("href");
//                 a.setAttribute("tabindex", "-1");
//             });

//         }

//         if (isMobile) {
//             appState.setShowSearchResult(true)
//             // const divSearch: HTMLDivElement|undefined = document.querySelector("#search.mobile") as HTMLDivElement
//             // console.log("Toggle", divSearch)
//             // if (divSearch) {
//                 // divSearch.style.left = ""
//             // }
//         }

//       // if (is_mobile_html()) toggle_info(true);
//       socket.close();
//     };

//   }
// }

// export function extractWord(word: string, html: string) {
//     if (!word) return word;

//     let initial = html.indexOf(word);
//     let subst = html.substring(initial - 50, initial - 1) + html.substring(initial, initial + 50);
//     let nonsymbols = "[^-!$%^&*()_+|~=\`{}\\[\\]:\\\";'<>?,.\\/ 「」]";
//     //console.log({word, initial, subst});

//     return subst.match(`(${nonsymbols}*${escapeRegex(word)}${nonsymbols}*)`)?.[1] || "";
// }

// function escapeRegex(string: string) {
//       return string.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
// }