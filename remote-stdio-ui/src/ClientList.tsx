// import { FaPlay } from 'react-icons/fa';

// import React, { useState } from 'react'
import { useEffect, useState } from 'react';
import './ClientList.css'

import type {AppState, Client} from './interfaces'
import { FaKeyboard } from 'react-icons/fa';
// import * as songUtils from './songUtils'
// import { startSession } from './utils';

interface ClientListProps {
  appState: AppState
  onClientOpen: (client_id: string)=> void
  isMobile?: boolean;
}

function ClientList(props: ClientListProps) {
  const [client_list, setClientList] = useState<Client[]>([])
  let chats = props.appState.chats

  useEffect(()=>{
    setClientList(props.appState.clients)
    for (let tmp of props.appState.clients) {
      console.log("Changed", tmp)
    }
  }, [props.appState.clients])

  if (props.isMobile) {
    return (
      <>
        <table className="tablecss">
          <thead>
            <tr>
              <th className="no">No.</th>
              <th className="item">Item</th>
            </tr>
          </thead>
          <tbody id="stamps"></tbody>
        </table>
      </>
    )
  } else {
    return (
      <>
      {/*
      <div className='clientlist controls'>
        <button type="button" className="clientlist control" onMouseUp={_ => songUtils.doClient(props.appState)}><FaPlay />Run</button>
      </div>
      */}
      <div id="clientListContainer">
        <table className="tablecss">
          <thead>
            <tr>
              <th className="no">Client Info</th>
            </tr>
          </thead>
          <tbody id="clients">
            {Object.entries(client_list).map(([_, client], index) =>(
              <tr key={index}>
                <td>
                  <div className='clients' onMouseUp={()=>props.onClientOpen(client.client_id)}>
                    <div className={client.client_id == props.appState.current_client ? 'selected' : ''}>{client.display_name} {chats[client.client_id]?.stdin_enabled ? <FaKeyboard /> : ''}</div>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      </>
    )
  }
}


export default ClientList