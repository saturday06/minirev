{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Network.HTTP.Client
import           Network.HTTP.ReverseProxy
import           Network.Wai
import           Network.Wai.Handler.Warp as Warp

main = do
  manager <- newManager $ defaultManagerSettings { managerConnCount = 5000, managerIdleConnectionCount = 5000 }
  let settings = Warp.setPort 3335 $ setHTTP2Disabled defaultSettings
  let dest = WPRProxyDest ProxyDest { pdHost = "127.0.0.1", pdPort = 8080 }
  runSettings settings $ proxyApp manager dest

proxyApp :: Manager -> WaiProxyResponse -> Application
proxyApp manager dest req res = do
  waiProxyTo (const $ return dest) defaultOnExc manager req res
