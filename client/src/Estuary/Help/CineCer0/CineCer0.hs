{-# LANGUAGE OverloadedStrings #-}
module Estuary.Help.CineCer0.CineCer0 where

import Reflex hiding (Request,Response)
import Reflex.Dom hiding (Request,Response)

import Estuary.Types.Context
import Estuary.Types.Language
import Estuary.Reflex.Utility
import Estuary.Widgets.Editor
import Data.Map.Strict

cineCer0Help :: MonadWidget t m => Editor t m ()
cineCer0Help = el "div" $ do
  aboutCineCer0
  examplesCineCer0


aboutCineCer0 :: MonadWidget t m => Editor t m ()
aboutCineCer0 = el "div" $ do
  dynText =<< (translatableText $ fromList [
    (English,"CineCer0 (pronounced \"sin–ay–ser-oh\") is a language for displaying and transforming videos and text in the browser. It can be used, for example, in the performance of live coded cinema, kinetic typography, VJ-ing, etc. Originally inspired by the CineVivo project, and created specifically for the Estuary platform during the SSHRC-funded research project \"Platforms and practices for networked, language- neutral live coding\". CineCer0 features an economical Haskell-like notation and a strongly declarative syntax."),
    (Español,"CineCer0 es un lenguaje para reproducir y transformar video, así como renderizar y transformar texto en el navegador. Puede ser usado, por ejemplo, para performance de live cinema con programación al vuelo, animación tipográfica, VJ-ing, etc. Este lenguaje fue originalmente inspirado en el proyecto CineVivo, y creado específicamente para correr en la plataforma de Estuary como parte del proyecto de investigación apoyado por SSHRC \"Platforms and practices for networked, language- neutral live coding\". CineCer0 presenta una notación económica parecida a la de Haskell, y con sintaxis declarativa.")
    ])


examplesCineCer0 :: MonadWidget t m => Editor t m ()
examplesCineCer0 = el "div" $ do
  dynText =<< (translatableText $ fromList [
    (English,"Examples:"),
    (Español,"Ejemplos:")
    ])
  el "ul" $ do
    el "li" $ elClass "div" "ieRef" $ text "every 30 1 $ circleMask 0.5 $ setSize 0.8 $ \"videos/hogweed.mov\""
    el "li" $ elClass "div" "ieRef" $ text "rgb 1 0 1 $ fontSize 600 $ setPosY (-0.6) $ text \"This is a text\""
