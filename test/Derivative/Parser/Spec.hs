{-# LANGUAGE FlexibleInstances, TypeSynonymInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Derivative.Parser.Spec where

import Control.Applicative
import Control.Monad
import Data.Higher.Graph
import Derivative.Parser
import Prelude hiding (abs)
import Test.Hspec
import Test.Hspec.QuickCheck
import Test.QuickCheck hiding (label)

{-# ANN module "HLint: ignore Redundant do" #-}
{-# ANN module "HLint: ignore Functor law" #-}
{-# ANN module "HLint: ignore Monad law, left identity" #-}
{-# ANN module "HLint: ignore Monad law, right identity" #-}

spec :: Spec
spec = do
  describe "parseNull" $ do
    describe "cat" $ do
      prop "returns pairs of its parse trees" $
        \ a b -> parseNull (parser $ pure a `cat` pure b) `shouldBe` [(a, b) :: (Char, Char)]

      prop "is empty when its left operand is empty" $
        \ b -> parseNull (parser $ empty `cat` pure b) `shouldBe` ([] :: [(Char, Char)])

      prop "is empty when its right operand is empty" $
        \ a -> parseNull (parser $ pure a `cat` empty) `shouldBe` ([] :: [(Char, Char)])

    describe "<|>" $ do
      prop "returns left parse trees" $
        \ a -> parseNull (pure a <|> empty) `shouldBe` [a :: Char]

      prop "returns right parse trees" $
        \ b -> parseNull (empty <|> pure b) `shouldBe` [b :: Char]

      prop "returns ambiguous parse trees" $
        \ a b -> parseNull (pure a <|> pure b) `shouldBe` [a, b :: Char]

    describe "many" $ do
      prop "contains the empty sequence" $
        \ p -> parseNull (many (getBlind p :: Parser Char)) `shouldBe` [[]]

    describe "fmap" $ do
      prop "applies a function to its parse trees" $
        \ c -> parseNull (fmap succ (parser $ lit c) `deriv` c) `shouldBe` [succ c]

    describe "lit" $ do
      prop "is empty" $
        \ a -> parseNull (parser $ lit a) `shouldBe` []

    describe "pure" $ do
      prop "returns parse trees" $
        \ a -> parseNull (pure (a :: Char)) `shouldBe` [a]

    describe "empty" $ do
      it "is empty" $
        parseNull (empty :: Parser Char) `shouldBe` []

    describe "ret" $ do
      prop "is identity" $
        \ t -> parseNull (parser (ret t) :: Parser Char) `shouldBe` t

    it "terminates on cyclic grammars" $
      let grammar = mu (\ a -> a <|> ret ["x"]) in
      parseNull grammar `shouldBe` ["x"]


  describe "deriv" $ do
    describe "many" $ do
      prop "produces a list of successful parses" $
        \ c -> parseNull (parser (many (lit c)) `deriv` c) `shouldBe` [[c]]

      prop "produces no parse trees when unsuccessful" $
        \ c -> parseNull (parser (many (lit c)) `deriv` succ c) `shouldBe` []

    describe "fmap" $ do
      prop "distributivity" $
        \ f c -> parseNull (fmap (getBlind f :: Char -> Char) (pure c)) `shouldBe` [getBlind f c]

    describe "lit" $ do
      prop "represents unmatched content with the empty parser" $
        \ a -> parser (lit a) `deriv` succ a `shouldBe` empty

      prop "represents matched content with ε reduction parsers" $
        \ a -> parser (lit a) `deriv` a `shouldBe` parser (ret [a])

    describe "<|>" $ do
      prop "distributivity" $
        \ a b c -> parser (lit a <|> lit b) `deriv` c `shouldBe` (parser (lit a) `deriv` c) <|> (parser (lit b) `deriv` c)

    describe "pure" $ do
      prop "has the null derivative" $
        \ a c -> pure (a :: Char) `deriv` c `shouldBe` empty

    it "terminates on cyclic grammars" $
      compact (lam `deriv` 'x') `shouldNotBe` empty

    describe "ret" $ do
      prop "annihilates" $
        \ a c -> parser (ret (a :: String)) `deriv` c `shouldBe` empty

    describe "label" $ do
      prop "distributivity" $
        \ c s -> parser (lit c `label` s) `deriv` c `shouldBe` parser (combinator (parser (lit c) `deriv` c) `label` s)

    describe "cat" $ do
      prop "does not pass through non-nullable parsers" $
        \ c -> parser (lit c `cat` lit (succ c)) `deriv` c `shouldBe` parser (ret [c] `cat` lit (succ c) <|> empty `cat` empty)

      prop "passes through nullable parsers" $
        \ c d -> parser (ret [c :: Char] `cat` lit d) `deriv` d `shouldBe` parser (empty `cat` lit d <|> ret [c] `cat` ret [d])


  describe "nullable" $ do
    describe "cat" $ do
      prop "is the conjunction of its operands’ nullability" $
        \ a b -> nullable (parser (unGraph a `cat` unGraph b)) `shouldBe` nullable (a :: Parser Char) && nullable (b :: Parser Char)

    describe "empty" $
      it "is not nullable" $
        nullable empty `shouldBe` False

    describe "ret" $
      prop "is nullable" $
        \ t -> nullable (parser (ret t) :: Parser Char) `shouldBe` True

    describe "ret" $
      prop "is nullable" $
        \ c -> nullable (parser (ret (c :: String))) `shouldBe` True


  describe "compaction" $ do
    prop "reduces parser size" $
      \ p -> size (compact p :: Parser Char) `shouldSatisfy` (<= size p)


  describe "Functor" $ do
    prop "obeys the identity law" $
      \ c -> parseNull (fmap id (parser $ lit c) `deriv` c) `shouldBe` parseNull (parser (lit c) `deriv` c)

    prop "obeys the composition law" $
      \ c f g -> parseNull (fmap (getBlind f :: Char -> Char) (fmap (getBlind g) (parser $ lit c)) `deriv` c) `shouldBe` parseNull (fmap (getBlind f . getBlind g) (parser $ lit c) `deriv` c)


  describe "Applicative" $ do
    prop "obeys the identity law" $
      \ v -> parseNull (pure id <*> parser (lit v) `deriv` v) `shouldBe` parseNull (parser (lit v) `deriv` v)

    prop "obeys the composition law" $
      \ u v w -> parseNull (pure (.) <*> (getBlind u :: Parser (Char -> Char)) <*> getBlind v <*> parser (lit w) `deriv` w) `shouldBe` parseNull (getBlind u <*> (getBlind v <*> parser (lit w)) `deriv` w)

    prop "obeys the homomorphism law" $
      \ x f -> parseNull (pure (getBlind f :: Char -> Char) <*> pure x) `shouldBe` parseNull (pure (getBlind f x))

    prop "obeys the interchange law" $
      \ u y -> parseNull ((getBlind u :: Parser (Char -> Char)) <*> pure y) `shouldBe` parseNull (pure ($ y) <*> getBlind u)

    prop "obeys the fmap identity" $
      \ f x -> parseNull (pure (getBlind f :: Char -> Char) <*> x) `shouldBe` parseNull (fmap (getBlind f) x)

    prop "obeys the return identity" $
      \ f -> pure (getBlind f :: Char -> Char) `shouldBe` (return (getBlind f :: Char -> Char) :: Parser (Char -> Char))

    prop "obeys the ap identity" $
      \ f x -> parseNull (pure (getBlind f :: Char -> Char) <*> x) `shouldBe` parseNull (pure (getBlind f :: Char -> Char) `ap` x)

    prop "obeys the left-discarding identity" $
      \ u v -> parseNull (u *> v) `shouldBe` parseNull (pure (const id) <*> (u :: Parser Char) <*> (v :: Parser Char))

    prop "obeys the right-discarding identity" $
      \ u v -> parseNull (u <* v) `shouldBe` parseNull (pure const <*> (u :: Parser Char) <*> (v :: Parser Char))


  describe "Alternative" $ do
    prop "obeys the some law" $
      \ v -> parseNull (some (getBlind v :: Parser Char)) `shouldBe` parseNull ((:) <$> getBlind v <*> many (getBlind v))

    prop "obeys the many law" $
      \ v -> parseNull (many (parser $ lit v)) `shouldBe` parseNull (some (parser $ lit v) <|> pure "")

    describe "(<|>)" $ do
      prop "is not right-biased" $
        \ c -> parseNull (parser (lit c <|> lit (succ c)) `deriv` c) `shouldBe` [c]

      prop "is not left-biased" $
        \ c -> parseNull (parser (lit (succ c) <|> lit c) `deriv` c) `shouldBe` [c]

      prop "returns ambiguous parses" $
        \ c -> parseNull (parser (lit c <|> lit c) `deriv` c) `shouldBe` [c, c]


  describe "Monad" $ do
    prop "obeys the left identity law" $
      \ k a -> parseNull (return (a :: Char) >>= getBlind k) `shouldBe` parseNull (getBlind k a :: Parser Char)

    prop "obeys the right identity law" $
      \ m -> parseNull (getBlind m >>= return) `shouldBe` parseNull (getBlind m :: Parser Char)


  describe "Show" $ do
    it "shows concatenations" $
      show (parser $ lit 'a' `cat` lit 'b') `shouldBe` "lit 'a' `cat` lit 'b'"

    it "terminates for cyclic grammars" $
      show cyclic `shouldBe` "Mu (\n  a => a `label` \"cyclic\"\n)\n"

    it "does not parenthesize left-nested alternations" $
      show (parser (lit 'a' <|> lit 'b' <|> lit 'c')) `shouldBe` "lit 'a' <|> lit 'b' <|> lit 'c'"

    it "parenthesizes right-nested alternations" $
      show (parser (lit 'a' <|> (lit 'b' <|> lit 'c'))) `shouldBe` "lit 'a' <|> (lit 'b' <|> lit 'c')"


  describe "size" $ do
    prop "is 1 for terminals" $
      \ a b -> let terminals = [ parser $ ret a, parser $ lit b, empty, parser (ret []) ] in sum (size <$> terminals) `shouldBe` length terminals

    prop "is 1 + the sum for unary nonterminals" $
      \ a s -> [ size (parser (fmap id (lit a))), size (parser (lit a >>= return)), size (parser (lit a `label` s)) ] `shouldBe` [ 2, 2, 2 ]

    prop "is 1 + the sum for binary nonterminals" $
      \ a b -> [ size (parser (lit a `cat` lit b)), size (parser (lit a <|> lit b)) ] `shouldBe` [ 3, 3 ]

    it "terminates on unlabelled acyclic grammars" $
      size (parser (lit 'c')) `shouldBe` 1

    it "terminates on labeled cyclic grammars" $
      size cyclic `shouldBe` 1

    it "terminates on interesting cyclic grammars" $
      size lam `shouldBe` 21


  describe "grammar" $ do
    it "parses a literal ‘x’ as a variable name" $
      varName `parse` "x" `shouldBe` ["x"]

    it "parses whitespace one character at a time" $
      parseNull (ws `deriv` ' ') `shouldBe` " "

    it "parses a single character string of whitespace" $
      ws `parse` " " `shouldBe` " "

    it "parses two characters of whitespace" $
      ((,) <$> ws <*> ws) `parse` "  " `shouldBe` [(' ', ' ')]

    it "parses repeated whitespace strings" $
      many ws `parse` "   " `shouldBe` [ "   " ]

    it "the derivative terminates on cyclic grammars" $
      (do { x <- return $! (deriv $! lam) 'x' ; x `seq` return True } ) `shouldReturn` True

    it "compaction terminates on cyclic grammars" $
      (do { x <- return $! compact $! (lam `deriv` 'x') ; x `seq` return True } ) `shouldReturn` True

    it "parses variables" $
      lam `parse` "x" `shouldBe` [ Var' "x" ]


-- Grammar

cyclic :: Parser ()
cyclic = mu $ \ v -> v `label` "cyclic"

varName :: Parser String
varName = parser $ literal "x"

ws :: Parser Char
ws = parser $ oneOf (lit <$> " \t\r\n") `label` "ws"

lam :: Parser Lam
lam = mu (\ lam ->
  let var = Var' . pure <$> lit 'x' `label` "var"
      app = (App <$> lam <*> (lit ' ' *> lam)) `label` "app"
      abs = (Abs . pure <$> (lit '\\' *> lit 'x') <*> (lit '.' *> lam)) `label` "abs" in
      abs <|> var <|> app `label` "lambda")


-- Types

data Lam = Var' String | Abs String Lam | App Lam Lam
  deriving (Eq, Show)


-- Instances

instance Arbitrary a => Arbitrary (Parser a) where
  arbitrary = oneof
    [ pure <$> arbitrary
    , pure empty
    , pure (parser (ret []))
    , (<|>) <$> arbitrary <*> arbitrary
    ]
