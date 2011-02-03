module SetBench (main) where

import Criterion.Main

import Data.Set
import qualified Data.Foldable as F
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as VM
import Control.Monad.Primitive
import Control.Monad
import Control.Monad.Trans
import Control.Monad.Random (getRandomR, RandT, StdGen, evalRandT, mkStdGen)
import qualified Data.ByteString.Char8 as BS
import qualified Progression.Main as P
import Control.DeepSeq

instance NFData BS.ByteString where
  rnf xs = xs `seq` ()

shuffle :: V.Vector a -> V.Vector a
shuffle = V.modify (\ mv -> evalRandT (shuffleM mv) (mkStdGen 0))

half :: V.Vector a -> V.Vector a
half xs = V.take (V.length xs `quot` 2) xs

shuffleM :: PrimMonad m => VM.MVector (PrimState m) a -> RandT StdGen m ()
shuffleM xs = forM_ [0..VM.length xs - 1] $ \ i -> do
  j <- getRandomR (0, VM.length xs - 1)
  lift $ VM.swap xs i j

sSortBench strings = toList (fromList strings)
sIntersectBench (strings, revs) = size (intersection (fromList strings) (fromList revs))
sLookupBench (strings, revs) = length [r | r <- revs, r `member` set]
  where set = fromList strings

sBenches strings revs = bgroup ""
  [bench "Lookup" (nf sLookupBench (strings, revs)),
    bench "Intersect" (nf sIntersectBench (strings, revs)),
    bench "Sort" (nf sSortBench strings)]

main :: IO ()
main = do
  strings <- liftM BS.lines (BS.readFile "dictionary.txt")
  let !strings' = V.toList (shuffle (V.fromList strings))
  let !revs' = Prelude.map BS.reverse strings'
  let benches = sBenches strings' revs'
  strings' `deepseq` revs' `deepseq` P.defaultMain benches