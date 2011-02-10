{-# LANGUAGE UnboxedTuples, TupleSections, PatternGuards, TypeFamilies, FlexibleInstances #-}

module Data.TrieMap.ProdMap () where

import Data.TrieMap.TrieKey

import Control.Monad
import Data.Functor
import Data.Foldable hiding (foldlM, foldrM)

import Prelude hiding (foldl, foldl1, foldr, foldr1)

instance (TrieKey k1, TrieKey k2) => Foldable (TrieMap (k1, k2)) where
  foldMap f (PMap m) = foldMap (foldMap f) m
  foldr f z (PMap m) = foldr (flip $ foldr f) z m
  foldl f z (PMap m) = foldl (foldl f) z m

-- | @'TrieMap' (k1, k2) a@ is implemented as a @'TrieMap' k1 ('TrieMap' k2 a)@.
instance (TrieKey k1, TrieKey k2) => TrieKey (k1, k2) where
	newtype TrieMap (k1, k2) a = PMap (TrieMap k1 (TrieMap k2 a))
	data Hole (k1, k2) a = PHole (Hole k1 (TrieMap k2 a)) (Hole k2 a)

	emptyM = PMap emptyM
	singletonM (k1, k2) = PMap . singletonM k1 . singletonM k2
	getSimpleM (PMap m) = getSimpleM m >>= getSimpleM
	sizeM (PMap m) = sizeM m
	lookupM (k1, k2) (PMap m) = lookupM k1 m >>= lookupM k2
	traverseM f (PMap m) = PMap <$> traverseM (traverseM f) m
	fmapM f (PMap m) = PMap (fmapM (fmapM f) m)
	mapMaybeM f (PMap m) = PMap (mapMaybeM (mapMaybeM' f) m)
	mapEitherM f (PMap m) = both PMap PMap (mapEitherM (mapEitherM' f)) m
	isSubmapM (<=) (PMap m1) (PMap m2) = isSubmapM (isSubmapM (<=)) m1 m2
	unionM f (PMap m1) (PMap m2) = PMap (unionM (unionM' f) m1 m2)
	isectM f (PMap m1) (PMap m2) = PMap (isectM (isectM' f) m1 m2)
	diffM f (PMap m1) (PMap m2) = PMap (diffM (diffM' f) m1 m2)
	insertWithM f (k1, k2) a (PMap m) = PMap (insertWithM f' k1 (singletonM k2 a) m) where
	  f' = insertWithM f k2 a
	
	fromAscListFold f = combineFold fromDistAscListFold (fromAscListFold f)
	fromDistAscListFold = combineFold fromDistAscListFold fromDistAscListFold

	singleHoleM (k1, k2) = PHole (singleHoleM k1) (singleHoleM k2)
	beforeM (PHole hole1 hole2) = PMap (beforeMM (gNull beforeM hole2) hole1)
	beforeWithM a (PHole hole1 hole2) = PMap (beforeWithM (beforeWithM a hole2) hole1)
	afterM (PHole hole1 hole2) = PMap (afterMM (gNull afterM hole2) hole1)
	afterWithM a (PHole hole1 hole2) = PMap (afterWithM (afterWithM a hole2) hole1)
	searchMC (k1, k2) (PMap m) f g = searchMC k1 m f' g' where
	  f' hole1 = f (PHole hole1 (singleHoleM k2))
	  g' m' hole1 = mapSearch (PHole hole1) (searchMC k2 m') f g
	indexM i (PMap m) = onThird (PHole hole1) (indexM i') m'
	  where	!(# i', m', hole1 #) = indexM i m
	extractHoleM (PMap m) = do
		(m', hole1) <- extractHoleM m
		(v, hole2) <- extractHoleM m'
		return (v, PHole hole1 hole2)
	
	clearM (PHole hole1 hole2) = PMap (fillHoleM (clearM' hole2) hole1)
	assignM a (PHole hole1 hole2) = PMap (assignM (assignM a hole2) hole1)
	
	unifierM (k1', k2') (k1, k2) a = case unifierM k1' k1 (singletonM k2 a) of
	  Just hole1	-> Just (PHole hole1 (singleHoleM k2'))
	  Nothing	-> PHole (singleHoleM k1) <$> unifierM k2' k2 a

gNull :: TrieKey k => (x -> TrieMap k a) -> x -> Maybe (TrieMap k a)
gNull = (guardNullM .)

combineFold :: Eq k1 => FromList k1 (TrieMap k2 a) -> FromList k2 a -> FromList (k1, k2) a
combineFold (Foldl snoc1 z01 done1) (Foldl snoc2 z02 done2) = Foldl snoc Nada done
  where	snoc stk (k1, k2) a = case stk of
	  Nada	-> Stack k1 z01 (snoc2 z02 k2 a)
	  Stack k10 stack1 stack2
	    | k1 == k10	-> Stack k10 stack1 (snoc2 stack2 k2 a)
	    | otherwise	-> Stack k1 (collapse stk) (snoc2 z02 k2 a)
	collapse Nada = z01
	collapse (Stack k1 stk1 stk2) = snoc1 stk1 k1 (done2 stk2)
	done = PMap . done1 . collapse

data Stack k1 z1 z2 = Nada | Stack k1 z1 z2