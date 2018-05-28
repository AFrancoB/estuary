module Estuary.Languages.Maria (maria) where

import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Number
import qualified Sound.Tidal.Context as Tidal
--Maria
-- Maria <nombre sonido> <transf1> <transf2>

lengExpr :: GenParser Char a Tidal.ParamPattern
lengExpr = do
--coloca aquí los parsers
  espacios
  string "Maria"
  espacios
  s <- sonidos
  espacios
  t1 <- trans
  espacios
  t2 <- trans
  espacios
  return $ t1 $ t2 $ nuestroTextoATidal s

nuestroTextoATidal ::  String  -> Tidal.ParamPattern
nuestroTextoATidal s = Tidal.s $ Tidal.p s

sonidos :: GenParser Char a String
sonidos = choice [
        --coloca aqui los nombres de tus muestras de audio
        --ej. try (string "bombo" >> espacios >> "bd")
        try (string "toca" >> espacios >> return "bd" ),
        try (string "abre" >> espacios >> return "arpy" ),
        try (string "cierra" >> espacios >> return "cp" ),
        try (string "tapa" >> espacios >> return "bass")
        ]

trans :: GenParser Char a (Tidal.ParamPattern -> Tidal.ParamPattern)
trans = choice [
              --coloca aqui los nombres de tus transformaciones
         try (string "rapido" >> spaces >> fractional3 False >>= return . Tidal.fast),
         try (string "lento" >> spaces >> fractional3 False >>= return . Tidal.slow),
         try (string "suave">> spaces >> fractional3 False >>= return . Tidal.density),
         try (string "puerta" >> spaces >> int >>= return . Tidal.chop),
         try (string "ventana">> spaces >> int >>= return . Tidal.striate),
         try (string "botella" >> spaces >> int >>= return . Tidal.iter),
         try (descartarTexto >> return id)
                ]

--descartar espacios
espacios :: GenParser Char a String
espacios = many (oneOf " ")

--descartar texto
descartarTexto :: GenParser Char a String
descartarTexto = many (oneOf "\n")

exprStack :: GenParser Char a Tidal.ParamPattern
exprStack = do
   expr <- many lengExpr
   return $ Tidal.stack expr

maria :: String -> Tidal.ParamPattern
maria s = either (const Tidal.silence) id $ parse exprStack "unNombreparaTuLenguage" s
