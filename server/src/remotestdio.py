# Thank you Gemini 2.5 Pro

import sys
import os
import threading
import json
import time
from urllib.parse import urlparse
import requests
import websocket  # `pip install websocket-client requests` が必要です
import builtins

class WhineThread(threading.Thread):
    """
    Ruby版のWhineThreadと同様に、スレッド内で発生した例外を
    標準エラー出力に表示するスレッドクラス。
    """
    def __init__(self, group=None, target=None, name=None, args=(), kwargs=None, *, daemon=None):
        super().__init__(group=group, target=target, name=name, args=args, kwargs=kwargs, daemon=daemon)
        self._target = target
        self._args = args
        self._kwargs = kwargs if kwargs is not None else {}

    def run(self):
        """スレッドの実行ロジックをラップし、例外を捕捉します。"""
        try:
            if self._target:
                self._target(*self._args, **self._kwargs)
        except Exception as e:
            # スレッド内で発生したエラーを標準エラー出力に書き出す
            sys.stderr.write(f"Error in thread {self.name}: {e}\n")
            import traceback
            sys.stderr.write(traceback.format_exc())

class WSIN:
    """
    WebSocketサーバーに接続し、メッセージを受信するためのクラス。
    RubyのWSINクラスのロジックを再現します。
    """
    def __init__(self, host, client_id):
        self.host = host
        self.client_id = client_id
        self.got_msg = False
        self.msg = ''

    def gets(self):
        """
        WebSocketサーバーからメッセージを受信するまでブロックします。
        接続が切れた場合は10秒待ってから再試行します。
        """
        while not self.got_msg:
            try:
                ws_url = f"ws://{self.host}/websocket/back"
                ws = websocket.create_connection(ws_url)
                try:
                    # 接続時にクライアントIDを送信
                    ws.send(self.client_id)
                    # メッセージを受信するまで待機
                    self.msg = ws.recv()
                    self.got_msg = True
                    return self.msg
                finally:
                    ws.close()
            except (websocket.WebSocketConnectionClosedException, ConnectionRefusedError, ConnectionResetError) as e:
                # メッセージ受信前に接続が閉じた場合、リトライする
                sys.stderr.write(f"WS connection issue: {e}. Retrying after 10s\n")
                time.sleep(10)
            except Exception as e:
                sys.stderr.write(f"An unexpected error occurred in WSIN: {e}\n")
                time.sleep(10)
        return self.msg

class FakeSTDStream:
    """
    sys.stdoutやsys.stderrを置き換えるためのファイル風オブジェクト。
    書き込まれた内容は、元のストリームとリモートエンドポイントの両方に送られます。
    """
    def __init__(self, original_stream, is_err=False):
        self.original_stream = original_stream
        self.is_err = is_err

    def write(self, msg):
        """
        メッセージを元のストリームとリモートの両方に書き込みます。
        """
        # 元のコンソールに書き込む
        self.original_stream.write(msg)
        self.original_stream.flush()
        # リモートエンドポイントに書き込む
        RemoteSTDIO.write(msg, err=self.is_err)

    def flush(self):
        """元のストリームをフラッシュします。"""
        self.original_stream.flush()

    def __getattr__(self, name):
        """
        writeとflush以外のメソッド・属性は、元のストリームオブジェクトに委譲します。
        """
        return getattr(self.original_stream, name)

class RemoteSTDIO:
    """
    標準入出力をリモートで処理するための主要なロジックを管理するクラス。
    RubyのRemoteSTDIOモジュールに相当します。
    """
    # --- クラスレベルの変数で状態を管理 ---
    _host = None
    _client_id = None
    _url = None
    _http_session = None
    _lock = threading.Lock()

    # --- オリジナルの組み込み関数とストリームを保存 ---
    _original_input = builtins.input
    # _original_input = input
    _original_stdout = sys.stdout
    _original_stderr = sys.stderr
    
    _is_initialized = False
    _is_patched = False

    @classmethod
    def init(cls, host, client_id):
        """
        リモート接続を初期化し、標準入出力をパッチします。
        """
        if cls._is_initialized:
            return
            
        cls._host = host
        cls._client_id = client_id
        
        # HTTPセッションの準備
        url_obj = urlparse(f"http://{host}/stdout")
        cls._url = url_obj.geturl()
        cls._http_session = requests.Session()
        
        cls._is_initialized = True
        cls._patch_io()

    @classmethod
    def write(cls, msg, err=False):
        """
        メッセージをJSONペイロードとしてリモートのHTTPサーバーにPOSTします。
        """

        if not msg  or msg == "\n":
            return

        if not cls._is_initialized:
            return

        payload = {
            'message': msg,
            'client_id': cls._client_id,
            'err': err
        }
        try:
            cls._http_session.post(cls._url, json=payload, timeout=5)
        except requests.exceptions.RequestException as e:
            # 元のstderrに書き出すことで無限ループを回避
            cls._original_stderr.write(f"Failed to send message to remote host: {e}\n")

    @classmethod
    def gets(cls, prompt=""):
        """
        ローカルの標準入力とリモートのWebSocketからの入力を同時に待ち受け、
        先に入力があった方を返します。
        """
        if not cls._is_initialized:
            return cls._original_input(prompt)
        
        # プロンプトがあれば先に出力しておく
        if prompt:
            sys.stdout.write(prompt)
            sys.stdout.flush()

        result = [None]  # スレッド間で共有するためのミュータブルなオブジェクト
        got_input_event = threading.Event()

        def read_local_input():
            """ローカルのコンソールからの入力を読み取るスレッド関数。"""
            try:
                local_val = cls._original_input()
                if not got_input_event.is_set():
                    with cls._lock:
                        if not got_input_event.is_set():
                            result[0] = local_val
                            got_input_event.set()
            except EOFError:
                # 入力が終了した場合（Ctrl+Dなど）
                pass
        
        def read_remote_input():
            """リモートのWebSocketからの入力を読み取るスread_remote_inputッド関数。"""
            wsin = WSIN(cls._host, cls._client_id)
            remote_val = wsin.gets()
            if not got_input_event.is_set():
                with cls._lock:
                    if not got_input_event.is_set():
                        result[0] = remote_val
                        got_input_event.set()
        
        # 2つの入力ソースを監視するスレッドを開始
        local_thread = WhineThread(target=read_local_input, daemon=True)
        remote_thread = WhineThread(target=read_remote_input, daemon=True)
        
        local_thread.start()
        remote_thread.start()

        # どちらかのスレッドが完了するのを待つ
        got_input_event.wait()
        
        # 結果を返す
        return result[0] or ''

    @classmethod
    def _patch_io(cls):
        """
        組み込みのinput関数とsys.stdout/stderrを置き換えます。
        """
        if cls._is_patched:
            return
            
        builtins.input = cls.gets
        sys.stdout = FakeSTDStream(cls._original_stdout, is_err=False)
        sys.stderr = FakeSTDStream(cls._original_stderr, is_err=True)
        
        cls._is_patched = True

class RemoteSTDIOUtils:
    """
    環境変数から初期化を行うためのユーティリティクラス。
    """
    @staticmethod
    def init_by_envvar():
        """
        環境変数 'HOST' と 'CID' を使ってRemoteSTDIOを初期化します。
        """
        host = os.getenv('HOST')
        client_id = os.getenv('CID')
        
        if host and client_id:
            RemoteSTDIO.init(host, client_id)
        else:
            # 元のstderrを使用
            RemoteSTDIO._original_stderr.write("WARN: 'HOST' or 'CID' env var not set. Using standard I/O.\n")


# --- メインの実行ブロック ---
if __name__ == "__main__":
    from datetime import datetime

    # 環境変数からHOSTとCIDを取得して初期化
    # 例: export HOST=localhost:3000 CID=my-client-123
    RemoteSTDIOUtils.init_by_envvar()

    # `print` は `sys.stdout` を経由してリモートに送信される
    print("## Hello from Python")
    print(f"**At {datetime.now().isoformat()}**")
    print("~~Test text~~")
    
    # `input` はローカルとリモートの両方で待機する
    # プロンプトは `gets` メソッド内で処理される
    val = input("Input >> ")

    # `sys.stderr` への書き込みもリモートに送信される
    sys.stderr.write(f"Got '{val}'\n")

    print(f"The received value is: {val!r}")