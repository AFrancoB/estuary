module Main where

import Data.Text (Text)
import Data.List ((\\))
import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Data.Map.Strict as Map
import qualified Network.WebSockets as WS
import Control.Monad
import Control.Concurrent.MVar
import Control.Exception (try)
import Text.JSON

import Estuary.Utility
import Estuary.Types.Definition
import Estuary.Types.Sited
import Estuary.Types.EnsembleRequest
import Estuary.Types.EnsembleResponse
import Estuary.Types.EditOrEval
import Estuary.Types.Ensemble
import Estuary.Types.Request
import Estuary.Types.Response
import Estuary.Types.View
import Estuary.Types.Client
import Estuary.Types.Server


main = do
  putStrLn "Estuary collaborative editing server (listening on port 8001)"
  server <- newMVar newServer
  WS.runServer "0.0.0.0" 8001 $ connectionHandler server

connectionHandler :: MVar Server -> WS.PendingConnection -> IO ()
connectionHandler s ws = do
  putStrLn "received new connection"
  ws' <- WS.acceptRequest ws
  ss <- takeMVar s
  let (h,ss') = addClient ss ws'
  putMVar s ss'
  WS.forkPingThread ws' 30
  getServerClientCount s >>= respondAll s . ServerClientCount
  processLoop ws' s h

processLoop :: WS.Connection -> MVar Server -> ClientHandle -> IO ()
processLoop ws s h = do
  m <- try $ WS.receiveData ws
  case m of
    Right x -> do
      let x' = decode (T.unpack x) :: Result JSString
      case x' of
        Ok x'' -> do
          processResult s h $ decode (fromJSString x'')
          processLoop ws s h
        Error x'' -> do
          putStrLn $ "Error: " ++ x''
          processLoop ws s h
    Left WS.ConnectionClosed -> close s h "unexpected loss of connection"
    Left (WS.CloseRequest _ _) -> close s h "connection closed by request from peer"
    Left (WS.ParseException e) -> do
      putStrLn ("parse exception: " ++ e)
      processLoop ws s h

close :: MVar Server -> ClientHandle -> String -> IO ()
close s h msg = do
  putStrLn $ "closing connection: " ++ msg
  updateServer s $ deleteClient h
  return ()


onlyIfAuthenticated :: MVar Server -> ClientHandle -> IO () -> IO ()
onlyIfAuthenticated s h f = do
  s' <- readMVar s
  let c = clients s' Map.! h
  if (authenticated c) then f else putStrLn "ignoring request from non-authenticated client"

onlyIfAuthenticatedInEnsemble :: MVar Server -> ClientHandle -> IO () -> IO ()
onlyIfAuthenticatedInEnsemble s h f = do
  s' <- readMVar s
  let c = clients s' Map.! h
  if (authenticatedInEnsemble c) then f else putStrLn "ignoring request from client not authenticated in ensemble"


processResult :: MVar Server -> ClientHandle -> Result ServerRequest -> IO ()
processResult _ c (Error x) = putStrLn ("Error: " ++ x)
processResult s c (Ok x) = processRequest s c x


processRequest :: MVar Server -> ClientHandle -> ServerRequest -> IO ()

processRequest s c (Authenticate x) = do
  pwd <- getPassword s
  if x == pwd 
    then do 
      putStrLn "received authenticate with correct password"
      updateClient s c $ \x -> x { authenticated = True } 
    else do
      putStrLn "received authenticate with wrong password"
      updateClient s c $ \x -> x { authenticated = False }

processRequest s c GetEnsembleList = onlyIfAuthenticated s c $ do
  putStrLn "GetEnsembleList"
  getEnsembleList s >>= respond s c

processRequest s c (JoinEnsemble x) = onlyIfAuthenticated s c $ do
  putStrLn $ "joining ensemble " ++ x
  updateClient s c $ \c' -> c' { ensemble = Just x }

processRequest s c LeaveEnsemble = onlyIfAuthenticated s c $ do
  putStrLn $ "leaving ensemble"
  updateClient s c $ \c' -> c' { ensemble = Nothing }

processRequest s c (CreateEnsemble name pwd) = onlyIfAuthenticated s c $ do
  putStrLn $ "CreateEnsemble " ++ name
  updateServer s $ createEnsemble name pwd
  getEnsembleList s >>= respondAll s

processRequest s c (EnsembleRequest x) = onlyIfAuthenticated s c $ processInEnsemble s c x

processRequest s c GetServerClientCount = do
  putStrLn "GetServerClientCount"
  getServerClientCount s >>= respond s c . ServerClientCount


processInEnsemble :: MVar Server -> ClientHandle -> Sited String (EnsembleRequest Definition) -> IO ()
processInEnsemble s c (Sited e x) = processEnsembleRequest s c e x

processEnsembleRequest :: MVar Server -> ClientHandle -> String -> EnsembleRequest Definition -> IO ()

processEnsembleRequest s c e x@(AuthenticateInEnsemble p2) = do
  p1 <- getEnsemblePassword s e
  let p2' = if p1 == "" then "" else p2
  if p1 == p2'
    then do
      putStrLn $ "successful AuthenticateInEnsemble in " ++ e
      updateClient s c $ setAuthenticatedInEnsemble True 
    else do
      putStrLn $ "failed AuthenticateInEnsemble in " ++ e
      updateClient s c $ setAuthenticatedInEnsemble False

processEnsembleRequest s c e x@(SendChat name msg) = do
  putStrLn $ "SendChat in " ++ e ++ " from " ++ name ++ ": " ++ msg
  respondEnsemble s e $ EnsembleResponse (Sited e (Chat name msg))

processEnsembleRequest s c e x@(ZoneRequest (Sited zone (Edit value))) = do
  putStrLn $ "Edit in (" ++ e ++ "," ++ (show zone) ++ "): " ++ (show value)
  updateServer s $ edit e zone value
  respondEnsembleNoOrigin s c e $ EnsembleResponse (Sited e (ZoneResponse (Sited zone (Edit value))))

processEnsembleRequest s c e x@(ZoneRequest (Sited zone (Evaluate value))) = do
  putStrLn $ "Eval in (" ++ e ++ "," ++ (show zone) ++ "): " ++ (show value)
  respondEnsembleNoOrigin s c e $ EnsembleResponse (Sited e (ZoneResponse (Sited zone (Evaluate value))))

processEnsembleRequest s c e GetViews = do
  putStrLn $ "GetViews in " ++ e
  vs <- getViews s e -- IO [Sited String View]
  forM_ vs $ \v -> respond s c (EnsembleResponse (Sited e (View v)))

processEnsembleRequest s c e x@(SetView (Sited key value)) = do
  putStrLn $ "SetView in (" ++ e ++ "," ++ key ++ "): " ++ (show value)
  updateServer s $ setView e key value
  respondEnsembleNoOrigin s c e $ EnsembleResponse (Sited e (View (Sited key value))) 

processEnsembleRequest s c e x@(TempoChange cps) = putStrLn "placeholder: TempoChange"

processEnsembleRequest _ _ _ _ = putStrLn "warning: action failed pattern matching"


send :: ServerResponse -> [Client] -> IO ()
send x = mapM_ $ \c -> WS.sendTextData (connection c) $ (T.pack . encodeStrict) x

respond :: MVar Server -> ClientHandle -> ServerResponse -> IO ()
respond s c x = withMVar s $ (send x) . (:[]) . (Map.! c)  . clients

respondAll :: MVar Server -> ServerResponse -> IO ()
respondAll s x = withMVar s $ (send x) . Map.elems . clients

respondAllNoOrigin :: MVar Server -> ClientHandle -> ServerResponse -> IO ()
respondAllNoOrigin s c x = withMVar s $ (send x) . Map.elems . Map.delete c . clients

respondEnsemble :: MVar Server -> String -> ServerResponse -> IO ()
respondEnsemble s e x = withMVar s $ (send x) . Map.elems . ensembleFilter e . clients 

respondEnsembleNoOrigin :: MVar Server -> ClientHandle -> String -> ServerResponse -> IO ()
respondEnsembleNoOrigin s c e x = withMVar s $ (send x) . Map.elems . Map.delete c . ensembleFilter e . clients

ensembleFilter :: String -> Map.Map ClientHandle Client -> Map.Map ClientHandle Client
ensembleFilter e = Map.filter $ (==(Just e)) . ensemble 

updateServer :: MVar Server -> (Server -> Server) -> IO (MVar Server)
updateServer s f = do
  s' <- takeMVar s
  putMVar s (f s')
  return s


