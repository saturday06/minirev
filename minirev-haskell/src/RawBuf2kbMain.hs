{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Data.Streaming.Network
import           Data.Conduit.Network
import           Network.HTTP.ReverseProxy

main = do
  let settings = setReadBufferSize (2 * 1024) $ serverSettings 3337 "127.0.0.1"
  runTCPServer settings $ \appData ->
    rawProxyTo
        (\_headers -> return $ Right $ ProxyDest "127.0.0.1" 8080)
        appData
