{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}
module Main where

import           Blaze.ByteString.Builder (Builder, fromByteString, fromLazyByteString, fromStorables)
import           Control.Monad
import           Control.Exception
import           Data.ByteString.Internal (ByteString(..))
import           Data.Maybe
import           Data.Streaming.Network
import           Data.String
-- import           Data.Word8
import           Network.HTTP.Client
import           Network.HTTP.Client.Internal hiding (Connection)
import           Network.HTTP.ReverseProxy
import           Network.HTTP.Types
import           Network.Wai as Wai
import           Network.Wai.Handler.Warp as Warp
import           Network.Wai.Handler.Warp.Types
import           Network.Wai.Handler.Warp.Run
import           Network.Wai.Handler.Warp.Buffer hiding (bufferSize)
import           Network.Wai.Handler.Warp.SendFile
import           Network.Wai.Handler.Warp.Recv
import           Network.Wai.Handler.Warp.Internal (runSettingsConnection)
import           Network.Socket
import qualified Network.Socket.ByteString as Sock
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as CBS
import qualified Data.ByteString.Lazy as LBS

main :: IO ()
main = do
  let settings = Warp.setPort 3335 defaultSettings
  let dest = WPRProxyDest ProxyDest { pdHost = "127.0.0.1", pdPort = 8080 }
  manager <- newManager $ defaultManagerSettings {
      managerConnCount = 5000
    , managerIdleConnectionCount = 5000
    , managerRawConnection = return $ openSocketConnectionSize (const $ return ()) goBufferSize
    }
  bracket (bindPortTCP (Warp.getPort settings) (Warp.getHost settings)) close $ \serverSocket -> do
    -- setInstallShutdownHandler settings close serverSocket
    let getConnection = do
            (clientSocket, clientSocketAddress) <- accept serverSocket
            setSocketCloseOnExec clientSocket
            setSocketOption clientSocket NoDelay 1
            connection <- do
              let
                bufferSize = goBufferSize + 4096
                sendAll = Sock.sendAll clientSocket
              bufferPool <- newBufferPool
              writeBuf <- allocateBuffer bufferSize
              return Connection {
                  connSendMany = Sock.sendMany clientSocket
                , connSendAll = sendAll
                , connSendFile = sendFile clientSocket writeBuf bufferSize sendAll
                , connRecv = receive clientSocket bufferPool
                , connClose = close clientSocket
                , connFree = freeBuffer writeBuf
                , connRecvBuf = receiveBuf clientSocket
                , connWriteBuffer = writeBuf
                , connBufferSize = bufferSize
                }
            return (connection, clientSocketAddress)
    runSettingsConnection settings getConnection $ proxyApp manager dest

proxyApp :: Manager -> WaiProxyResponse -> Application
proxyApp manager dest req res = do
  waiProxyTo (const $ return dest) defaultOnExc manager req res
