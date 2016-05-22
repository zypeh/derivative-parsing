{-# LANGUAGE RankNTypes, TypeOperators #-}
module Data.Higher.Product where

import Data.Higher.Bifunctor
import Data.Higher.Functor
import Data.Higher.Transformation

infixr :*:

data (:*:) f g a = f a :*: g a

-- | Retrieve the first field of a higher product.
hfst :: (f :*: g) ~> f
hfst (f :*: _) = f

-- | Retrieve the second field of a higher product.
hsnd :: (f :*: g) ~> g
hsnd (_ :*: g) = g


infixr `hdistribute`

hdistribute :: HFunctor f => (f c ~> c') -> (f d ~> d') -> f (c :*: d) ~> (c' :*: d')
hdistribute f g p = f (hfmap hfst p) :*: g (hfmap hsnd p)


-- Instances

instance HBifunctor (:*:)
  where f `hbimap` g = \ (a :*: b) -> f a :*: g b
