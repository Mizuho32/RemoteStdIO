import { useEffect, useRef, useState } from 'react'
/*
import reactLogo from './assets/react.svg'
import viteLogo from '/vite.svg'
*/
import './App.css'

import type { AppState, Client } from './interfaces'
// import * as utils from './utils'
import axios from 'axios'
import ClientList from './ClientList'
import * as AppModules from './AppModules'
import ChatList from './ChatList'

const title = 'Remote StdIO';
const change = ' *';

function App() {
  const [appState, setAppState] = useState<AppState>({clients: [], chats: {}, clients_hidden: false, tab_active: true})
  const appStateRef = useRef(appState)
  // msgs: [], stdin_disabled: true
  const hasRun = useRef(false)

  useEffect(() => {
    // Run once
    if (hasRun.current) return
    hasRun.current = true

    const main = async () => {
      const current_client_id = localStorage.getItem('rmtstdio.current_client')
      try {
        AppModules.startWebSocket(setAppState)
        const results = await axios.get<Client[]>(`/api/clients`);
        if (results.status === 200) {
          // for (let client of results.data) {
          //   console.log("client", client)
          //   // appState.clients = [...appState.clients, client]
          // }
          setAppState(prev => ({...prev, clients: results.data}))
          if (current_client_id) await AppModules.onClientOpen(current_client_id, appStateRef, setAppState)
        }
      } catch (error) {
        alert(`Error fetching data\n${error}`);
      }
    };
    main();

    // Favicon notify preparation
    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        setAppState(prev => ({...prev, tab_active: true}))
        document.title = title;
      } else {
        setAppState(prev => ({...prev, tab_active: false}))
      }
    };

    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => {
      // document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
  }, [])

  useEffect(() => {
    appStateRef.current = appState;
  }, [appState]);

  // favicon notify
  useEffect(()=> {
    const curAppState = appStateRef.current;
    const stdin_enabled_exists = Object.values(curAppState.chats).some(chat => chat.stdin_enabled);
    const cur_title = document.title;
    // console.log(`appState.chats change, ${curAppState.tab_active} ${stdin_enabled_exists} ${cur_title}`)

    if (!curAppState.tab_active && stdin_enabled_exists && cur_title == title) {
      document.title = document.title + change;
    }
  }, [appState.chats])




  return (
    <>
      <div id="client-list-container">
        <ClientList appState={appState} onClientOpen={(cid)=>AppModules.onClientOpen(cid, appStateRef, setAppState)} onClientsHidden={()=>AppModules.onClientsHidden(true, appState, setAppState)}></ClientList>
        {/*
        <h1>Vite + React</h1>
        <div className="card">
          <button onClick={() => setCount((count) => ({ value: count.value + 1 }))}>
            count is {count.value}
          </button>
          <p>
            Edit <code>src/App.tsx</code> and save to test HMR
          </p>
        </div>
        */}
      </div>
      <div id="chat-container">
        {
          appState.clients.map(client => 
          <ChatList appState={appState} client={client} style={client.client_id == appState.current_client ? 'block' : 'none' } key={client.client_id}
            onClientsShown={()=>AppModules.onClientsHidden(false, appState, setAppState)} incrementalLoad={async ()=> await AppModules.incrementalLoad(client.client_id, 10, true, appStateRef, setAppState)}></ChatList>
          )
        }
        {/*<ChatList appState={appState} ></ChatList>*/}
      </div>
    </>
  )
}

export default App
