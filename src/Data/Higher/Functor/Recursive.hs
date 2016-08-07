{-# LANGUAGE FlexibleContexts, FlexibleInstances, MultiParamTypeClasses, PolyKinds, RankNTypes, TypeFamilies, TypeOperators #-}
module Data.Higher.Functor.Recursive where

import Data.Higher.Functor
import Data.Higher.Functor.Fix
import Data.Higher.Transformation


-- Types

data Free f v a
  = Pure (v a)
  | Impure (f (Free f v) a)


iter :: HFunctor f => (f a ~> a) -> Free f a ~> a
iter algebra a = case a of
  Pure a -> a
  Impure r -> algebra (hfmap (iter algebra) r)


-- Classes

type family Base (t :: k -> *) :: (k -> *) -> k -> *

class HFunctor (Base t) => HRecursive t where
  hproject :: t ~> Base t t

  hcata :: (Base t a ~> a) -> t ~> a
  hcata f = f . hfmap (hcata f) . hproject

class HFunctor (Base t) => HCorecursive t where
  hembed :: Base t t ~> t

  hana :: (a ~> Base t a) -> a ~> t
  hana f = hembed . hfmap (hana f) . f


-- Instances

type instance Base (Fix f) = f

instance HFunctor f => HRecursive (Fix f) where
  hproject = unFix

instance HFunctor f => HCorecursive (Fix f) where
  hembed = Fix
