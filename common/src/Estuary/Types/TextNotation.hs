{-# LANGUAGE DeriveDataTypeable #-}

module Estuary.Types.TextNotation where

import Text.JSON
import Text.JSON.Generic

import Estuary.Types.TidalParser

data TextNotation =
  TidalTextNotation TidalParser |
  Punctual |
  SuperContinent |
  SvgOp |
  CanvasOp |
  CineCer0
  deriving (Read,Eq,Ord,Data,Typeable,Show)

textNotationDropDownLabel :: TextNotation -> String
textNotationDropDownLabel (TidalTextNotation x) = show x
textNotationDropDownLabel x = show x

instance JSON TextNotation where
  showJSON = toJSON
  readJSON = fromJSON
