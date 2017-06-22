{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Network.HTTP.Client
import           Network.HTTP.Types
import           Network.Wai
import           Network.Wai.Handler.Warp as Warp
import Control.Monad
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Blaze.ByteString.Builder (fromByteString, fromLazyByteString)
import Data.String

main = do
  manager <- newManager $ defaultManagerSettings { managerConnCount = 5000, managerIdleConnectionCount = 5000 }
  let settings = Warp.setPort 3334 defaultSettings
  runSettings settings $ proxyApp manager

proxyApp :: Manager -> Application
proxyApp manager request sendResponse = do
  sendResponse $ responseStream status200 [] $ \write flush -> do
    upstreamRequest <- (\r -> r { path = rawPathInfo request }) <$> parseRequest "http://127.0.0.1:8080"
    withResponse upstreamRequest manager $ \upstreamResponse -> do
      let loop = do
            body <- brRead (responseBody upstreamResponse)
            case BS.null body of
              True -> return ()
              _ -> do
                     write $ fromByteString body
                     loop
      loop
