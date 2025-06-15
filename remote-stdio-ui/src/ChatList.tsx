import { IoSendSharp, IoClose } from "react-icons/io5";

// import React, { useState } from 'react'
import { useEffect, useLayoutEffect, useRef, useState, /*useSyncExternalStore*/ } from 'react';
import * as module from './ChatListModules'
import './ChatList.css'

import type {AppState, Client, Message} from './interfaces'
// import * as songUtils from './songUtils'
// import { startSession } from './utils';

interface ChatListProps {
  appState: AppState
  style: string
  client: Client
  /*scrollBottomRef: React.RefObject<HTMLDivElement | null>*/
  isMobile?: boolean;
}

function ChatList(props: ChatListProps) {
  const [msg_list, setMsgList] = useState<Message[]>([])
  const [stdin_enabled, setStdinEnabled] = useState(false)
  const scrollBottomRef = useRef<HTMLDivElement>(null);

  let chat = props.appState.chats[props.client.client_id]
  let client_id = props.client.client_id

  function scroll() {
    scrollBottomRef?.current?.scrollIntoView({behavior: 'smooth'});
  }

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

  useLayoutEffect(() => {
    scroll()
  }, []);
  useLayoutEffect(() => {
  scroll()
  }, [msg_list]);



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
          <div className='msgsUI'>
            <table className="tablecss" id="chat">
              <thead onClick={()=>scroll()}>
                <tr>
                  <th className="no">Chat {props.client.display_name}</th>
                </tr>
              </thead>
              <tbody id="msgs">
                {Object.entries(msg_list).map(([_, msg], index) => (
                  <tr key={index}>
                    <td>
                      <div className='msgs'>
                        <div className='msg'>{msg.message}</div>
                        <div>{msg.datetime.toISOString()}</div>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {/* 一番下までスクロールするためのdiv↓ */}
            <div ref={/*props.*/scrollBottomRef}/>
        </div>
        <div id={`stdinUI_${client_id}`} className='stdinUI'>
          <textarea id={`stdin_${client_id}`} disabled={!stdin_enabled} className='stdin'></textarea>
          <div className="send" >
            <button type="button" id={`send_${client_id}`} disabled={!stdin_enabled} onClick={_=>module.onButtonClick(client_id)}><IoSendSharp /></button>
            <button type="button" id={`cancel_${client_id}`} ><IoClose /></button>
          </div>
        </div>
      </div>
      </>
    )
  }
}


export default ChatList