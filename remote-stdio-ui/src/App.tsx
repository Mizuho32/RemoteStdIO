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

function App() {
  const [appState, setAppState] = useState<AppState>({clients: [], chats: {}, clients_hidden: false})
  // msgs: [], stdin_disabled: true
  const hasRun = useRef(false)

  useEffect(() => {
    // Run once
    if (hasRun.current) return
    hasRun.current = true

    const main = async () => {
      try {
        AppModules.startWebSocket(setAppState)
        const results = await axios.get<Client[]>(`/api/clients`);
        if (results.status === 200) {
          // for (let client of results.data) {
          //   console.log("client", client)
          //   // appState.clients = [...appState.clients, client]
          // }
          setAppState(prev => ({...prev, clients: results.data}))
        }
      } catch (error) {
        alert(`Error fetching data\n${error}`);
      }
    };
    main();
  }, [])



  return (
    <>
      <div id="client-list-container">
        <ClientList appState={appState} onClientOpen={(cid)=>AppModules.onClientOpen(cid, appState, setAppState)} onClientsHidden={()=>AppModules.onClientsHidden(true, appState, setAppState)}></ClientList>
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
          <ChatList appState={appState} client={client} style={client.client_id == appState.current_client ? 'block' : 'none' } key={client.client_id} onClientsShown={()=>AppModules.onClientsHidden(false, appState, setAppState)}></ChatList>
          )
        }
        {/*<ChatList appState={appState} ></ChatList>*/}
      </div>
    </>
  )
}

export default App
