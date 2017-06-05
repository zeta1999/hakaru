{-# LANGUAGE OverloadedStrings,
             PatternGuards,
             DataKinds,
             KindSignatures,
             GADTs,
             FlexibleContexts,
             TypeOperators
             #-}

module Main where

import qualified Language.Hakaru.Syntax.AST as T
import           Language.Hakaru.Syntax.AST.Transforms
import           Language.Hakaru.Syntax.ABT
import           Language.Hakaru.Syntax.TypeCheck

import           Language.Hakaru.Types.Sing
import           Language.Hakaru.Types.DataKind

import           Language.Hakaru.Pretty.Haskell
import           Language.Hakaru.Command
import           Language.Hakaru.Summary

import           Data.Text                  as TxT
import qualified Data.Text.IO               as IO
import           Data.Monoid ((<>))
import           System.IO (stderr)
import           Text.PrettyPrint    hiding ((<>))
import           Options.Applicative hiding (header,footer)
import           System.FilePath


data Options =
  Options { fileIn          :: String
          , fileOut         :: Maybe String
          , asModule        :: Maybe String
          , logFloatPrelude :: Bool
          , optimize        :: Bool
          } deriving Show

main :: IO ()
main = do
  opts <- parseOpts
  compileHakaru opts

parseOpts :: IO Options
parseOpts = execParser $ info (helper <*> options)
                       $ fullDesc <> progDesc "Compile Hakaru to Haskell"

{-

There is some redundancy in Compile.hs, Hakaru.hs, and HKC.hs in how we decide
what to run given which arguments. There may be a way to unify these.

-}

options :: Parser Options
options = Options
  <$> strArgument (  metavar "INPUT"
                  <> help "Program to be compiled" )
  <*> (optional $ strOption (  short 'o'
                            <> help "Optional output file name"))
  <*> (optional $ strOption (  long "as-module"
                            <> short 'M'
                            <> help "creates a haskell module with this name"))
  <*> switch (  long "logfloat-prelude"
             <> help "use logfloat prelude for numeric stability")
  <*> switch (  short 'O'
             <> help "perform Hakaru AST optimizations" )



prettyProg :: (ABT T.Term abt)
           => String
           -> abt '[] a
           -> String
prettyProg name ast =
    renderStyle style
    (cat [ text (name ++ " = ")
         , nest 2 (pretty ast)
         ])

compileHakaru
    :: Options
    -> IO ()
compileHakaru opts = do
    let file = fileIn opts
    prog <- readFromFile file
    case parseAndInfer prog of
      Left err                 -> IO.hPutStrLn stderr err
      Right (TypedAST typ ast) -> do
        ast' <- (if optimize opts then optimizations else id) <$> summary (et ast)
        writeHkHsToFile file (fileOut opts) . TxT.unlines $
          header (logFloatPrelude opts) (asModule opts) ++
          [ pack $ prettyProg "prog" ast' ] ++
          (case asModule opts of
             Nothing -> footer typ
             Just _  -> [])
  where et = expandTransformations

writeHkHsToFile :: String -> Maybe String -> Text -> IO ()
writeHkHsToFile inFile moutFile content =
  let outFile =  case moutFile of
                   Nothing -> replaceFileName inFile (takeBaseName inFile) ++ ".hs"
                   Just x  -> x
  in  writeToFile outFile content

header :: Bool -> Maybe String -> [Text]
header logfloats mmodule =
  [ "{-# LANGUAGE DataKinds, NegativeLiterals #-}"
  , TxT.unwords [ "module"
                , case mmodule of
                    Just m  -> pack m
                    Nothing -> "Main"
                , "where" ]
  , ""
  , if logfloats
    then TxT.unlines [ "import           Data.Number.LogFloat (LogFloat)"
                     , "import           Prelude              hiding (product, exp, log, (**))"
                     ]
    else "import           Prelude hiding (product)"
  , if logfloats
    then TxT.unlines [ "import           Language.Hakaru.Runtime.LogFloatPrelude"
                     , "import           Language.Hakaru.Runtime.LogFloatCmdLine" ]
    else TxT.unlines [ "import           Language.Hakaru.Runtime.Prelude"
                     , "import           Language.Hakaru.Runtime.CmdLine" ]
  , "import           Language.Hakaru.Types.Sing"
  , "import qualified System.Random.MWC                as MWC"
  , "import           Control.Monad"
  , "import           System.Environment (getArgs)"
  , ""
  ]

footer :: Sing (a :: Hakaru) -> [Text]
footer typ =
    ["","main :: IO ()"
    , TxT.concat ["main = makeMain (prog :: ",toHsType typ,")  =<< getArgs"]]
  where toHsType :: Sing (a :: Hakaru) -> Text
        toHsType SInt = "Int"
        toHsType SNat = "Int"
        toHsType SReal = "Double"
        toHsType SProb = "LogFloat"
        toHsType (SArray t) = let t' = toHsType t in
                                TxT.concat ["(",TxT.unwords ["MayBoxVec",t',t'],")"]
        toHsType (SMeasure t) = TxT.concat ["(",TxT.unwords ["Measure",toHsType t],")"]
        toHsType (SFun t1 t2) = TxT.unwords [toHsType t1,"->",toHsType t2]
        toHsType (SData _
                   ((SKonst t1 `SEt` SKonst t2 `SEt` SDone) `SPlus` SVoid)) =
          TxT.concat ["(",toHsType t1,",",toHsType t2,")"]
        toHsType _ = "type"

footerWalk :: [Text]
footerWalk =
  [ ""
  , "main :: IO ()"
  , "main = do"
  , "  g <- MWC.createSystemRandom"
  , "  x <- prog2 g"
  , "  iterateM_ (withPrint $ flip prog1 g) x"
  ]
