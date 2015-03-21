{-# LANGUAGE OverloadedStrings #-}
module Main where

import Prelude hiding (length, readFile, writeFile)
import Data.ByteString.Char8 (ByteString, readFile, writeFile, length)
import System.Environment (getArgs)
import System.Exit (exitSuccess)
import Text.ParserCombinators.Parsec (ParseError)

import FuncTorrent.Bencode (decode, BVal(..))
import FuncTorrent.Logger (initLogger, logMessage, logStop)
import FuncTorrent.Metainfo (announce, lengthInBytes, mkMetaInfo, info, name)
import FuncTorrent.Peer (getPeers, getPeerResponse, handShakeMsg)
import FuncTorrent.Tracker (connect, prepareRequest)

logError :: ParseError -> (String -> IO ()) -> IO ()
logError e logMsg = logMsg $ "parse error: \n" ++ show e

peerId :: String
peerId = "-HS0001-*-*-20150215"

exit :: IO ByteString
exit = exitSuccess

usage :: IO ()
usage = putStrLn "usage: functorrent torrent-file"

parse :: [String] -> IO ByteString
parse [] = usage >> exit
parse [a] = readFile a
parse _ = exit

main :: IO ()
main = do
    args <- getArgs
    logR <- initLogger
    let logMsg = logMessage logR
    logMsg $ "Parsing input file: " ++ concat args
    torrentStr <- parse args
    case decode torrentStr of
      Right d ->
          case mkMetaInfo d of
            Nothing -> logMsg "parse error"
            Just m -> do
              logMsg "Input File OK"

              let len = lengthInBytes $ info m
                  (Bdict d') = d

              logMsg "Trying to fetch peers: "
              body <- connect (announce m) (prepareRequest d' peerId len)

              -- TODO: Write to ~/.functorrent/caches
              writeFile (name (info m) ++ ".cache") body

              let peerResponse = show $ getPeers $ getPeerResponse body
              logMsg $ "Peers List : " ++ peerResponse

              let hsMsgLen = show $ length $ handShakeMsg d' peerId
              logMsg $ "Hand-shake message length : " ++ hsMsgLen

      Left e -> logError e logMsg
    logStop logR
