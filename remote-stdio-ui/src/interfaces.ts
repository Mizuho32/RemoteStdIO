
export interface Client {
    display_name: string
    client_id: string
}


export interface Message {
    message: string
    datetime: Date
    _id: string
    client_id: string
    err: boolean
}

// cmds
export interface Stdin {
    status: string
    client_id?: string
    message?: string
}

/*
export interface Extracts {
    [pid: string]: Extract
}

export interface Extract {
    artist: string
    filename: string
    current_song: string
}

type Cookie = {
    [x: string]: any;
}

export interface APIReturn {
    status: boolean
    value: string
}

*/

export interface Chat {
    msgs?: Message[]
    stdin_enabled?: boolean
}

export interface AppState {
    clients: Client[]
    chats: {[client_id: string]: Chat}
    current_client?: string
    clients_hidden: boolean
}
/*
    filename: string
    artist: string
    songList: Song[]
    streamList: Stream[]
    extractList: Extracts
    extractWS?: WebSocket
    audioEl?: HTMLAudioElement
    cookies: Cookie
    showSearchResult: boolean
    //isMobile: boolean

    setSongList: React.Dispatch<React.SetStateAction<Song[]>>
    setStreamList: React.Dispatch<React.SetStateAction<Stream[]>>
    setExtractList: React.Dispatch<React.SetStateAction<Extracts>>
    setFilename: React.Dispatch<React.SetStateAction<string>>
    setArtist: React.Dispatch<React.SetStateAction<string>>
    setCookie: (name: string, value: any, options?: any) => void
    removeCookie: (name: string, options?: any) => void
    setShowSearchResult: React.Dispatch<React.SetStateAction<boolean>>
    //setIsMobile: React.Dispatch<React.SetStateAction<boolean>>
}
*/

// export default Client