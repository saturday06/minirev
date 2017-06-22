{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Data.Conduit.Network
import           Network.HTTP.ReverseProxy

main = do
  let settings = serverSettings 3336 "127.0.0.1"
  runTCPServer settings $ \appData ->
    rawProxyTo
        (\_headers -> return $ Right $ ProxyDest "127.0.0.1" 8080)
        appData
