module Derivative.Parser.Char.Spec where

import Data.Char
import Derivative.Parser
import Derivative.Parser.Char
import Test.Hspec
import Test.Hspec.QuickCheck

spec :: Spec
spec = do
  describe "alphaNum" $ do
    prop "parses isAlphaNum characters" $
      \ c -> null (parser alphaNum `parse` [c]) `shouldBe` not (isAlphaNum c)

  describe "letter" $ do
    prop "parses isLetter characters" $
      \ c -> null (parser letter `parse` [c]) `shouldBe` not (isLetter c)
