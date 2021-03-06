{-# LANGUAGE TypeFamilies, FlexibleContexts, FlexibleInstances, UndecidableInstances, DeriveFunctor, StandaloneDeriving #-}
{-# LANGUAGE DeriveTraversable #-}
module Data.TrieMap.Class (TMap(..), TSet(..), TKey, Rep, TrieMap, TrieKey) where

import Data.TrieMap.TrieKey
import Data.TrieMap.Representation.Class

import Prelude hiding (foldr, foldl, foldl1, foldr1)

-- | A map from keys @k@ to values @a@, backed by a trie.
newtype TMap k a = TMap {getTMap :: TrieMap (Rep k) (Assoc k a)}

deriving instance TKey k => Functor (TMap k)
deriving instance TKey k => Traversable (TMap k)

-- | A set of values @a@, backed by a trie.
newtype TSet a = TSet {getTSet :: TrieMap (Rep a) (Elem a)}

-- | @'TKey' k@ is a handy alias for @('Repr' k, 'TrieKey' ('Rep' k))@.  To make a type an instance of 'TKey',
-- create a 'Repr' instance that will satisfy @'TrieKey' ('Rep' k)@, possibly using the Template Haskell methods
-- provided by "Data.TrieMap.Representation".
class (Repr k, TrieKey (Rep k)) => TKey k

instance (Repr k, TrieKey (Rep k)) => TKey k

instance TKey k => Foldable (TMap k) where
	foldMap f (TMap m) = foldMap (foldMap f) m
	foldr f z (TMap m) = foldr (flip $ foldr f) z m
	foldl f z (TMap m) = foldl (foldl f) z m