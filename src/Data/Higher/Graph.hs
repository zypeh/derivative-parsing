{-# LANGUAGE RankNTypes, ScopedTypeVariables, TypeOperators #-}
module Data.Higher.Graph
( HRec(..)
, HGraph(..)
, hgfold
, gfold
, hfold
, fold
, hcfold
, cfold
, hsfold
, sfold
, transform
, hgmap
, hpjoin
, modifyGraph
) where

import Control.Applicative
import Data.Function
import Data.Functor.Eq
import Data.Higher.Bifunctor
import Data.Higher.Eq
import Data.Higher.Functor
import Data.Higher.Functor.Eq
import Data.Higher.Functor.Show
import Data.Higher.Transformation

data HRec f v a
  = Var (v a)
  | Mu ([v a] -> [f (HRec f v) a])
  | In (f (HRec f v) a)

newtype HGraph f a = HDown { hup :: forall v. HRec f v a }


-- Folds

hgfold :: forall f v c. HFunctor f => (v ~> c) -> (forall a. ([v a] -> [c a]) -> c a) -> (f c ~> c) -> HGraph f ~> c
hgfold var bind recur = trans . hup
  where trans :: forall a. HRec f v a -> c a
        trans (Var x) = var x
        trans (Mu g) = bind (map (recur . hfmap trans) . g)
        trans (In fa) = recur (hfmap trans fa)

gfold :: forall f v c a. HFunctor f => (forall a. v a -> c) -> (forall a. ([v a] -> [c]) -> c) -> (forall a. f (Const c) a -> c) -> HGraph f a -> c
gfold var bind recur = getConst . hgfold (Const . var) (Const . bind . (fmap getConst .)) (Const . recur)

hfold :: HFunctor f => (f c ~> c) -> (forall a. c a) -> HGraph f ~> c
hfold alg k = hgfold id (\ g -> head (g (repeat k))) alg

fold :: HFunctor f => (forall b. f (Const a) b -> a) -> a -> HGraph f b -> a
fold alg k = getConst . hfold (Const . alg) (Const k)

hcfold :: HFunctor f => (f t ~> t) -> HGraph f ~> t
hcfold = hgfold id (head . fix)

cfold :: HFunctor f => (forall b. f (Const a) b -> a) -> HGraph f b -> a
cfold alg = getConst . hcfold (Const . alg)

hsfold :: (HFunctor f, HEq c) => (f c ~> c) -> (forall a. c a) -> HGraph f ~> c
hsfold alg k = hgfold id (head . fhfixVal (repeat k)) alg

sfold :: (HFunctor f, Eq a) => (forall b. f (Const a) b -> a) -> a -> HGraph f b -> a
sfold alg k = getConst . hsfold (Const . alg) (Const k)


-- Maps

transform :: forall f g. (HFunctor f, HFunctor g) => (forall h. f h ~> g h) -> HGraph f ~> HGraph g
transform f x = HDown (hmap (hup x))
  where hmap :: HRec f v ~> HRec g v
        hmap (Var x) = Var x
        hmap (Mu g) = Mu (map (f . hfmap hmap) . g)
        hmap (In x) = In (f (hfmap hmap x))

hgmap :: (HBifunctor f, HFunctor (f a), HFunctor (f b)) => (a ~> b) -> HGraph (f a) ~> HGraph (f b)
hgmap f = transform (hfirst f)

hpjoin :: HFunctor f => HRec f (HRec f v) a -> HRec f v a
hpjoin (Var x) = x
hpjoin (Mu g) = Mu (map (hfmap hpjoin) . g . map Var)
hpjoin (In r) = In (hfmap hpjoin r)

modifyGraph :: (forall v. HRec f v ~> HRec f v) -> HGraph f ~> HGraph f
modifyGraph f g = HDown (f (hup g))


-- Equality

instance HEqF f => Eq (HGraph f a)
  where a == b = eqRec 0 (hup a) (hup b)

eqRec :: HEqF f => Int -> HRec f (Const Int) a -> HRec f (Const Int) a -> Bool
eqRec n a b = case (a, b) of
  (Var x, Var y) -> x == y
  (Mu g, Mu h) -> let a = g (iterate (modifyConst succ) (Const n))
                      b = h (iterate (modifyConst succ) (Const n)) in
                      and $ zipWith (heqF (eqRec (n + length a))) a b
  (In x, In y) -> heqF (eqRec n) x y
  _ -> False


-- Show

instance HShowF f => Show (HGraph f a)
  where showsPrec n = showsRec (iterate (modifyConst succ) (Const 'a')) n . hup

showsRec :: HShowF f => (forall b. [Const Char b]) -> Int -> HRec f (Const Char) a -> ShowS
showsRec s n rec = case rec of
  Var c -> showChar (getConst c)
  Mu f -> let r = f s
              (fr, s') = splitAt (length r) s in
              showString "Mu (\n" . foldr (.) id
                [ showString "  " . showChar (getConst a) . showString " => " . v . showString "\n"
                | (a, v) <- zip fr (map (hshowsPrecF n (showsRec s')) r) ] . showString ")\n"
  In fa -> hshowsPrecF n (showsRec s) fa


-- Implementation details

fhfixVal :: (EqF f, HEq h) => f (h a) -> (f (h a) -> f (h a)) -> f (h a)
fhfixVal v f = if eqF heq v v' then v else fhfixVal v' f
  where v' = f v

modifyConst :: (a -> b) -> Const a ~> Const b
modifyConst f = Const . f . getConst
