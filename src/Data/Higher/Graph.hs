{-# LANGUAGE RankNTypes, ScopedTypeVariables, TypeOperators #-}
module Data.Higher.Graph where

import Control.Applicative
import Data.Function
import Data.Higher.Functor
import Data.Higher.Transformation

data HRec h v a
  = Var (v a)
  | Mu ([v a] -> [h (HRec h v) a])
  | In (h (HRec h v) a)

newtype HGraph h a = HDown { hup :: forall v. HRec h v a }

gfold :: forall h v c a. HFunctor h => (forall a. v a -> c) -> (forall a. ([v a] -> [c]) -> c) -> (forall a. h (Const c) a -> c) -> HGraph h a -> c
gfold var bind recur = getConst . trans . hup
  where trans :: HRec h v ~> Const c
        trans (Var x) = Const $ var x
        trans (Mu g) = Const $ bind (map (recur . hfmap trans) . g)
        trans (In fa) = Const $ recur (hfmap trans fa)

fold :: HFunctor h => (forall b. h (Const a) b -> a) -> a -> HGraph h b -> a
fold alg k = gfold id (\ g -> head (g (repeat k))) alg

cfold :: HFunctor h => (forall b. h (Const a) b -> a) -> HGraph h b -> a
cfold = gfold id (head . fix)

sfold :: (HFunctor h, Eq a) => (forall b. h (Const a) b -> a) -> a -> HGraph h b -> a
sfold alg k = gfold id (head . fixVal (repeat k)) alg

fixVal :: Eq a => a -> (a -> a) -> a
fixVal v f = if v == v' then v else fixVal v' f
  where v' = f v

hgfold :: forall f v c. HFunctor f => (v ~> c) -> (forall a. ([v a] -> [c a]) -> c a) -> (f c ~> c) -> HGraph f ~> c
hgfold var bind recur = trans . hup
  where trans :: forall a. HRec f v a -> c a
        trans (Var x) = var x
        trans (Mu g) = bind (map (recur . hfmap trans) . g)
        trans (In fa) = recur (hfmap trans fa)
