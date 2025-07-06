import { IoSendSharp, IoClose } from "react-icons/io5";

import { useEffect, useLayoutEffect, useRef, useState, /*useSyncExternalStore*/ } from 'react';
import { Tooltip } from 'react-tooltip';
import * as module from './ChatListModules'
import './ChatList.css'

import type {AppState, Client, Message} from './interfaces'
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

interface ChatListProps {
  appState: AppState
  style: string
  client: Client
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
      <div id="chatContainer" style={{display: props.style}}>
          <div className='msgsUI'>
            <div id="chat">
              <div className="chatheader" onClick={()=>scroll()}>
                  <h2 className="no">Chat {props.client.display_name}</h2>
              </div>
              <div className="msgs">
                <div>
                  {Object.entries(msg_list).map(([_, msg], index) => (
                    <div key={index}>
                          <div className='msg' data-tooltip-id={`${client_id}-${index}`} data-tooltip-content={`${msg.datetime.toLocaleDateString()} ${msg.datetime.toLocaleTimeString()}`}>
                            <ReactMarkdown remarkPlugins={[remarkGfm]}>{msg.message.replace(/\n/g, "  \n")}</ReactMarkdown>
                          </div>
                          <Tooltip id={`${client_id}-${index}`} />
                    </div>
                  ))}
                </div>
                {/* 一番下までスクロールするためのdiv↓ */}
                <div ref={/*props.*/scrollBottomRef}/>
              </div>
            </div>
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