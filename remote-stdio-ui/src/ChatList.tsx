// import { FaPlay } from 'react-icons/fa';

// import React, { useState } from 'react'
import { useEffect, useState, useSyncExternalStore } from 'react';
import * as module from './ChatListModules'
import './ChatList.css'

import type {AppState, Client, Message} from './interfaces'
// import * as songUtils from './songUtils'
// import { startSession } from './utils';

interface ChatListProps {
  appState: AppState
  style: string
  client: Client
  isMobile?: boolean;
}

function ChatList(props: ChatListProps) {
  const [msg_list, setMsgList] = useState<Message[]>([])
  const [stdin_enabled, setStdinEnabled] = useState(false)

  let chat = props.appState.chats[props.client.client_id]

  useEffect(()=>{
    const chat = props.appState.chats[props.client.client_id]
    if (chat?.msgs) {
      console.log("Effect MSG")
      for (let tmp of chat.msgs) {
        console.log("Effect msg", tmp)
      }
      setMsgList(chat.msgs)
    }
  }, [chat?.msgs])

  useEffect(()=>{
    if (chat?.stdin_enabled !== undefined)
      setStdinEnabled(chat?.stdin_enabled)
  }, [chat?.stdin_enabled])

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
      <div className='msglist controls'>
        <button type="button" className="msglist control" onMouseUp={_ => songUtils.doChat(props.appState)}><FaPlay />Run</button>
      </div>
      */}
      <div id="chatContainer" style={{display: props.style}}>
        <table className="tablecss" id="chat">
          <thead>
            <tr>
              <th className="no">Chat {props.client.display_name}</th>
            </tr>
          </thead>
          <tbody id="msgs">
            {Object.entries(msg_list).map(([_, msg], index) =>(
              <tr key={index}>
                <td>
                  <div className='msgs'>
                    <div>{msg.message}</div>
                    <div>{msg.datetime.toISOString()}</div>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <div id="stdinUI">
          <textarea id="stdin" disabled={!stdin_enabled}></textarea>
          <button type="button" className="msglist control" onMouseUp={()=>{}} id="send" disabled={!stdin_enabled} onClick={_=>module.onButtonClick(props.client.client_id)}>Run</button>
        </div>
      </div>
      </>
    )
  }
}


export default ChatList