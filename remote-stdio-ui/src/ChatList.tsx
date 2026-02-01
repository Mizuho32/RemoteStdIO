import { IoSendSharp, IoClose, IoChatboxEllipses } from "react-icons/io5";
import { MdOutlineKeyboardDoubleArrowRight } from "react-icons/md";
import { buildStyles, CircularProgressbar } from 'react-circular-progressbar';
import 'react-circular-progressbar/dist/styles.css';

import { useEffect, useLayoutEffect, useRef, useState, /*useSyncExternalStore*/ } from 'react';
import { Tooltip } from 'react-tooltip';
import * as module from './ChatListModules'
import './ChatList.css'

import type {AppState, Client, Message} from './interfaces'
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import rehypeRaw from 'rehype-raw'
import asciidoctor from 'asciidoctor' // (1)

export interface PrependState {
  prevScrollHeight: number
  prevScrollTop: number
  prepending: boolean
}

export interface ChatListProps {
  appState: AppState
  style: string
  client: Client
  onClientsShown: ()=>void
  incrementalLoad: ()=>Promise<void>
  isMobile?: boolean;
}

export interface WheeRefreshState {
  wheelUpCount: number
  timeout_handle?: number
  timeout_disapear_handle?: number
  fireCount: number
  showCount: number
  Timeout: number
  Timeout_slow: number
  Timeout_disapear: number
}

function ChatList(props: ChatListProps) {
  const [firstView, setFirstView] = useState<boolean>(true)
  const [msg_list, setMsgList] = useState<Message[]>([])
  const [stdin_enabled, setStdinEnabled] = useState(false)
  const [wheelRefreshState, setWheelRefreshState] = useState({wheelUpCount: 0,  fireCount: 9, showCount: 3, Timeout: 500, Timeout_slow: 1500, Timeout_disapear: 1000})
  const scrollBottomRef = useRef<HTMLDivElement>(null);
  const prependRef = useRef<PrependState>({ prevScrollHeight: 0, prevScrollTop: 0, prepending: false });

  let chat = props.appState.chats[props.client.client_id]
  let client_id = props.client.client_id
  
  const message_format = props.client.message_format
  const markdown = message_format?.includes('a') ? false : true
  const has_html = (text) => text.includes('<object')
  const Asciidoctor = markdown ? undefined : asciidoctor()


  useEffect(()=>{
    const chat = props.appState.chats[props.client.client_id]
    if (chat?.msgs) {
      // console.log("Effect MSG")
      // for (let tmp of chat.msgs) {
      //   console.log("Effect msg", tmp)
      // }
      setMsgList(chat.msgs)
    }
  }, [chat?.msgs])

  useEffect(()=>{
    if (chat?.stdin_enabled !== undefined)
      setStdinEnabled(chat?.stdin_enabled)
  }, [chat?.stdin_enabled])

  useLayoutEffect(() => {
    module.scroll(true, props, client_id, scrollBottomRef)

    // Wheel refresh firer
    const container = scrollBottomRef.current?.parentElement
    if (container) {
      const onWheel = (e: WheelEvent)=>module.onWheel(e, container, wheelRefreshState, setWheelRefreshState, props.incrementalLoad, prependRef)
      container?.addEventListener('wheel', onWheel);

      let startY: number|undefined = undefined
      const onTouchStart = function(ev: TouchEvent) {
          const touch = ev.touches[0];
          startY = touch.clientY;
      }
      const onTouchMove = function(ev: TouchEvent) {
        module.onPull(ev, container, wheelRefreshState, setWheelRefreshState, props.incrementalLoad, prependRef, startY)
      }
      const onTouchEnd = function() {
        startY = 0
      }
      container?.addEventListener('touchstart', onTouchStart);
      container?.addEventListener('touchend', onTouchEnd);
      container?.addEventListener('touchmove',  onTouchMove);
      return () => {
        container?.removeEventListener('wheel', onWheel)
        container?.removeEventListener('touchstart', onTouchStart)
        container?.removeEventListener('touchend', onTouchEnd);
        container?.removeEventListener('touchmove',  onTouchMove);
      };
    }

  }, []);
  useLayoutEffect(() => {
    //         true until first success scroll
    if (module.scroll(firstView, props, client_id, scrollBottomRef)) {
      setFirstView(false)
    }

    const container = scrollBottomRef.current?.parentElement
    if (prependRef.current.prepending && container) {
      const { prevScrollHeight, prevScrollTop } = prependRef.current;

      const newScrollHeight = container.scrollHeight;
      const diff = newScrollHeight - prevScrollHeight;

      container.scrollTop = prevScrollTop + diff;

      // リセット
      prependRef.current.prepending = false;
    }
  }, [msg_list]);


  let percentage = Math.max(Math.floor((wheelRefreshState.wheelUpCount - wheelRefreshState.showCount)/(wheelRefreshState.fireCount - wheelRefreshState.showCount) * 100), 0)
  let showLoad = wheelRefreshState.wheelUpCount > wheelRefreshState.showCount && wheelRefreshState.wheelUpCount <= wheelRefreshState.fireCount
  let pathColor = percentage >= 100 ? 'green' : 'blue'

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
              <div className="chatheader" onClick={()=>module.scroll(true, props, client_id, scrollBottomRef)}>
                  <h2 className="no">
                    {props.appState.clients_hidden ? <span onClick={_ => module.showClients(props)}><MdOutlineKeyboardDoubleArrowRight /></span> : <></>}
                    <span><IoChatboxEllipses /></span>{props.client.display_name}<span className="load-circle">{
                      (showLoad) && (<CircularProgressbar value={percentage} styles={buildStyles({pathColor: pathColor, pathTransitionDuration: 0,})} strokeWidth={16} />)
                    }</span>
                </h2>
              </div>
              <div className="msgs">
                {/* <ReactPullToRefresh onRefresh={async ()=>await console.log('Pulled')} className="your-own-class-if-you-want" style={{ textAlign: 'center' }}> */}
                <div>
                  {Object.entries(msg_list).map(([_, msg], index) => (
                    <div key={index}>
                          <div className='msg' data-tooltip-id={`${client_id}-${index}`} data-tooltip-content={`${msg.datetime.toLocaleDateString()} ${msg.datetime.toLocaleTimeString()}`}>
                            {
                              markdown ?
                                ( has_html(msg.message) ?
                                 /* FIXME: html mode selection UI */
                                  <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeRaw]}>{msg.message.replace(/\n/g, "  \n")}</ReactMarkdown> :
                                  <ReactMarkdown remarkPlugins={[remarkGfm]}>{msg.message.replace(/\n/g, "  \n")}</ReactMarkdown>) :
                                <div dangerouslySetInnerHTML={{ __html: Asciidoctor?.convert(msg.message.replace(/(?<!\n)\n(?!\n)/g, "  +\n"), {attributes: {showtitle: true}}) || '' }} />
                            }
                          </div>
                          <Tooltip id={`${client_id}-${index}`} />
                    </div>
                  ))}
                </div>
                {/* 一番下までスクロールするためのdiv↓ */}
                <div ref={/*props.*/scrollBottomRef}/>
                {/* </ReactPullToRefresh> */}
              </div>
            </div>
        </div>
        <div id={`stdinUI_${client_id}`} className='stdinUI'>
          <div className="stdins">
            <textarea id={`stdin_${client_id}`} disabled={!stdin_enabled} className='stdin plain'></textarea>
            <input id={`stdin_${client_id}_pw`} disabled={!stdin_enabled} className='stdin pw' type='password'></input>
          </div>
          <div className={`send ${stdin_enabled ? 'enabled' : 'disabled'}`} >
            <button type="button" id={`send_${client_id}`} disabled={!stdin_enabled} onClick={_=>module.onButtonClick(client_id)}><IoSendSharp /></button>
            <button type="button" id={`cancel_${client_id}`} ><IoClose /></button>
            <button type="button" id={`cancel_${client_id}`} ><IoClose /></button>
          </div>
        </div>
      </div>
      </>
    )
  }
}


export default ChatList
