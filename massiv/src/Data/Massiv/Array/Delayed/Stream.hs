{-# LANGUAGE CPP #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
-- |
-- Module      : Data.Massiv.Array.Delayed.Stream
-- Copyright   : (c) Alexey Kuleshevich 2019
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Massiv.Array.Delayed.Stream
  ( DS(..)
  , toStreamArray
  , filterS
  , filterA
  , filterM
  , mapMaybeS
  , mapMaybeA
  , mapMaybeM
  , unfoldr
  , unfoldrN
  ) where

import Control.Applicative
import Control.Monad (void)
import Data.Coerce
import Data.Massiv.Array.Delayed.Pull
import qualified Data.Massiv.Array.Manifest.Vector.Stream as S
import Data.Massiv.Core.Common
import GHC.Exts

-- | Delayed array that will be loaded in an interleaved fashion during parallel
-- computation.
data DS = DS

newtype instance Array DS Ix1 e = DSArray
  { dsArray :: S.Steps S.Id e
  }

instance Functor (Array DS Ix1) where

  fmap f = coerce . fmap f . dsArray
  {-# INLINE fmap #-}

instance Applicative (Array DS Ix1) where

  pure = DSArray . S.singleton
  {-# INLINE pure #-}

  (<*>) a1 a2 = DSArray (S.zipWith ($) (coerce a1) (coerce a2))
  {-# INLINE (<*>) #-}

#if MIN_VERSION_base(4,10,0)
  liftA2 f a1 a2 = DSArray (S.zipWith f (coerce a1) (coerce a2))
  {-# INLINE liftA2 #-}
#endif

instance Monad (Array DS Ix1) where

  return = DSArray . S.singleton
  {-# INLINE return #-}

  (>>=) arr f = coerce (S.concatMap (coerce . f) (dsArray arr))
  {-# INLINE (>>=) #-}


instance Foldable (Array DS Ix1) where

  foldr f acc (DSArray sts) = S.foldr f acc sts
  {-# INLINE foldr #-}

  length = S.length . coerce
  {-# INLINE length #-}

  -- TODO: add more


instance Semigroup (Array DS Ix1 e) where

  (<>) a1 a2 = DSArray (coerce a1 `S.append` coerce a2)
  {-# INLINE (<>) #-}


instance Monoid (Array DS Ix1 e) where

  mempty = DSArray S.empty
  {-# INLINE mempty #-}

  mappend = (<>)
  {-# INLINE mappend #-}

instance IsList (Array DS Ix1 e) where
  type Item (Array DS Ix1 e) = e

  fromList = DSArray . S.fromList
  {-# INLINE fromList #-}

  fromListN n = DSArray . S.fromListN n
  {-# INLINE fromListN #-}

  toList = S.toList . coerce
  {-# INLINE toList #-}


instance S.Stream DS Ix1 e where
  toStream = coerce
  {-# INLINE toStream #-}


-- | Flatten an array into a stream of values.
--
-- @since 0.4.1
toStreamArray :: Source r ix e => Array r ix e -> Array DS Ix1 e
toStreamArray = DSArray . S.steps
{-# INLINE toStreamArray #-}

instance Construct DS Ix1 e where
  setComp _ arr = arr
  {-# INLINE setComp #-}

  makeArrayLinear _ (Sz k) = DSArray . S.generate k
  {-# INLINE makeArrayLinear #-}


instance Extract DS Ix1 e where
  unsafeExtract sIx newSz = DSArray . S.slice sIx (unSz newSz) . dsArray
  {-# INLINE unsafeExtract #-}

-- | /O(n)/ - `size` implementation.
instance Load DS Ix1 e where
  size = SafeSz . S.length . coerce
  {-# INLINE size #-}

  getComp _ = Seq
  {-# INLINE getComp #-}

  loadArrayM _scheduler arr uWrite =
    case stepsSize (dsArray arr) of
      S.Exact _ ->
        void $ S.foldlM (\i e -> uWrite i e >> pure (i + 1)) 0 (S.transStepsId (coerce arr))
      _ -> error "Loading Stream array is not supported with loadArrayM"
  {-# INLINE loadArrayM #-}

  unsafeLoadIntoS marr (DSArray sts) =
    S.unstreamIntoM marr (stepsSize sts) (stepsStream sts)
  {-# INLINE unsafeLoadIntoS #-}

  unsafeLoadInto marr arr = liftIO $ unsafeLoadIntoS marr arr
  {-# INLINE unsafeLoadInto #-}



-- cons :: e -> Array DS Ix1 e -> Array DS Ix1 e
-- cons e = coerce . S.cons e . dsArray
-- {-# INLINE cons #-}

-- uncons :: Array DS Ix1 e -> Maybe (e, Array DS Ix1 e)
-- uncons = coerce . S.uncons . dsArray
-- {-# INLINE uncons #-}

-- snoc :: Array DS Ix1 e -> e -> Array DS Ix1 e
-- snoc (DSArray sts) e = DSArray (S.snoc sts e)
-- {-# INLINE snoc #-}


-- TODO: skip the stride while loading
-- instance StrideLoad DS Ix1 e where
--   loadArrayWithStrideM scheduler stride resultSize arr uWrite =
--     let strideIx = unStride stride
--         DIArray (DArray _ _ f) = arr
--     in loopM_ 0 (< numWorkers scheduler) (+ 1) $ \ !start ->
--           scheduleWork scheduler $
--           iterLinearM_ resultSize start (totalElem resultSize) (numWorkers scheduler) (<) $
--             \ !i ix -> uWrite i (f (liftIndex2 (*) strideIx ix))
--   {-# INLINE loadArrayWithStrideM #-}


-- | Right unfolding function. Useful when we do not have any idea ahead of time on how
-- many elements the vector will have.
--
-- ====__Example__
--
-- >>> unfoldr (\i -> if i < 9 then Just (i*i, i + 1) else Nothing) (0 :: Int)
-- Array DS Seq (Sz1 9)
--   [ 0, 1, 4, 9, 16, 25, 36, 49, 64 ]
-- >>> unfoldr (\i -> if sqrt i < 3 then Just (i * i, i + 1) else Nothing) (0 :: Double)
-- Array DS Seq (Sz1 9)
--   [ 0.0, 1.0, 4.0, 9.0, 16.0, 25.0, 36.0, 49.0, 64.0 ]
--
-- @since 0.4.1
unfoldr :: (s -> Maybe (e, s)) -> s -> Array DS Ix1 e
unfoldr f = DSArray . S.unfoldr f
{-# INLINE unfoldr #-}


-- | Right unfolding function with limited number of elements.
--
-- >>> unfoldrN 9 (\i -> Just (i*i, i + 1)) (0 :: Int)
-- Array DS Seq (Sz1 9)
--   [ 0, 1, 4, 9, 16, 25, 36, 49, 64 ]
--
-- @since 0.4.1
unfoldrN ::
     Sz1
  -- ^ Maximum number of elements that the vector can have
  -> (s -> Maybe (e, s))
  -- ^ Unfolding function. Stops when `Nothing` is reaturned or maximum number of elements
  -- is reached.
  -> s -- ^ Inititial element.
  -> Array DS Ix1 e
unfoldrN n f = DSArray . S.unfoldrN n f
{-# INLINE unfoldrN #-}



filterS :: S.Stream r ix e => (e -> Bool) -> Array r ix e -> Array DS Ix1 e
filterS f = DSArray . S.filter f . S.toStream
{-# INLINE filterS #-}

filterA :: (S.Stream r ix e, Applicative f) => (e -> f Bool) -> Array r ix e -> f (Array DS Ix1 e)
filterA f arr = DSArray <$> S.filterA f (S.toStream arr)
{-# INLINE filterA #-}

filterM :: (S.Stream r ix e, Monad m) => (e -> m Bool) -> Array r ix e -> m (Array DS Ix1 e)
filterM = filterA
{-# INLINE filterM #-}



mapMaybeS :: S.Stream r ix a => (a -> Maybe b) -> Array r ix a -> Array DS Ix1 b
mapMaybeS f = DSArray . S.mapMaybe f . S.toStream
{-# INLINE mapMaybeS #-}

mapMaybeA ::
     (S.Stream r ix a, Applicative f) => (a -> f (Maybe b)) -> Array r ix a -> f (Array DS Ix1 b)
mapMaybeA f arr = DSArray <$> S.mapMaybeA f (S.toStream arr)
{-# INLINE mapMaybeA #-}

mapMaybeM :: (S.Stream r ix a, Monad m) => (a -> m (Maybe b)) -> Array r ix a -> m (Array DS Ix1 b)
mapMaybeM = mapMaybeA
{-# INLINE mapMaybeM #-}


