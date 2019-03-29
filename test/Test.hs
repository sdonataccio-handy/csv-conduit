{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Main where

import           Control.Exception
import qualified Data.ByteString.Char8          as B
import           Data.Map                       ((!))
import           Data.Monoid                    as M
import           Data.Text
import qualified Data.Vector                    as V
import           System.Directory
import           Test.Framework                 (Test, defaultMain, testGroup)
import           Test.Framework.Providers.HUnit
import           Test.HUnit                     (assertFailure, (@=?))

import           Data.CSV.Conduit
import           Data.CSV.Conduit.Conversion


main :: IO ()
main = defaultMain tests


tests :: [Test]
tests =
  [ testGroup "Basic Ops" baseTests
  , testGroup "decodeCSV" decodeCSVTests
  ]


baseTests :: [Test]
baseTests =
  [ testCase "mapping with id works"              test_identityMap
  , testCase "simple parsing works"               (test_simpleParse testFile2)
  , testCase "simple parsing works for Mac-Excel" (test_simpleParse testFile3)
  ]


decodeCSVTests :: [Test]
decodeCSVTests =
  [ testCase "parses a CSV" $ do
      let efoos = decodeCSV defCSVSettings ("Foo\nfoo" :: B.ByteString)
      case efoos :: Either SomeException (V.Vector (Named Foo)) of
        Left e     -> assertFailure (show e)
        Right foos -> V.fromList [Named Foo] @=? foos
  , testCase "eats parse errors, evidently" $ do
      let efoos = decodeCSV defCSVSettings ("Foo\nbad" :: B.ByteString)
      case efoos :: Either SomeException (V.Vector (Named Foo)) of
        Left e     -> assertFailure (show e)
        Right foos -> M.mempty @=? foos
  ]


data Foo = Foo deriving (Show, Eq)


instance FromNamedRecord Foo where
  parseNamedRecord nr = do
    s <- nr .: "Foo"
    case s of
      "foo" -> pure Foo
      _     -> fail ("Expected \"foo\" but got " <> B.unpack s)


instance ToNamedRecord Foo where
  toNamedRecord Foo = namedRecord ["Foo" .= ("foo" :: B.ByteString)]


test_identityMap :: IO ()
test_identityMap = do
    _ <- runResourceT $ mapCSVFile csvSettings f testFile2 outFile
    f1 <- readFile testFile2
    f2 <- readFile outFile
    f1 @=? f2
    removeFile outFile
  where
    outFile = "test/testOut.csv"
    f :: Row Text -> [Row Text]
    f = return


test_simpleParse :: FilePath -> IO ()
test_simpleParse testFile = do
  (d :: V.Vector (MapRow B.ByteString)) <- readCSVFile csvSettings testFile
  V.mapM_ assertRow d
  where
    assertRow r = v3 @=? (v1 + v2)
      where v1 = readBS $ r ! "Col2"
            v2 = readBS $ r ! "Col3"
            v3 = readBS $ r ! "Sum"


csvSettings :: CSVSettings
csvSettings = defCSVSettings { csvQuoteChar = Just '`'}

testFile1, testFile2, testFile3 :: FilePath
testFile1 = "test/test.csv"
testFile2 = "test/test.csv"
testFile3 = "test/test-mac-excel.csv"

readBS :: B.ByteString -> Int
readBS = read . B.unpack
