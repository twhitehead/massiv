{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MonoLocalBinds        #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
module Data.Massiv.Array.MutableSpec (spec) where

import           Control.Concurrent.Async
import           Control.Monad.ST
import           Data.Functor.Identity
import           Data.List                        as L (sort)
import           Data.Massiv.Array.Mutable.Atomic
import           Data.Massiv.Array.Unsafe
import           Data.Massiv.CoreArbitrary        as A
import           Data.Proxy
import           Test.Hspec
import           Test.QuickCheck
import           Test.QuickCheck.Function
import           Test.QuickCheck.Monadic

prop_MapMapM :: (Show (Array r ix Int), Eq (Array r ix Int), Mutable r ix Int) =>
                r -> Proxy ix -> Fun Int Int -> ArrTiny D ix Int -> Property
prop_MapMapM r _ f (ArrTiny arr) =
  computeAs r (A.map (apply f) arr) === runIdentity (A.mapMR r (return . apply f) arr)

prop_iMapiMapM :: (Show (Array r ix Int), Eq (Array r ix Int), Mutable r ix Int) =>
                r -> Proxy ix -> Fun (ix, Int) Int -> ArrTiny D ix Int -> Property
prop_iMapiMapM r _ f (ArrTiny arr) =
  computeAs r (A.imap (curry (apply f)) arr) ===
  runIdentity (A.imapMR r (\ix e -> return $ apply f (ix, e)) arr)


prop_generateMakeST ::
     (Show (Array r ix Int), Eq (Array r ix Int), Construct r ix Int, Mutable r ix Int)
  => r
  -> Proxy ix
  -> Arr r ix Int
  -> Property
prop_generateMakeST _ _ (Arr arr) =
  arr === runST (generateArray (getComp arr) (size arr) (return . evaluate' arr))

prop_generateMakeIO :: (Show (Array r ix Int), Eq (Array r ix Int), Mutable r ix Int) =>
                             r -> Proxy ix -> Arr r ix Int -> Property
prop_generateMakeIO _ _ (Arr arr) = monadicIO $ do
  arr' <- run $ generateArrayIO (getComp arr) (size arr) (evaluateM arr)
  return (arr === arr')

prop_atomicModifyIntArrayMany :: ArrIx P Ix2 Int -> Array B Ix1 Int -> Property
prop_atomicModifyIntArrayMany (ArrIx arr ix) barr =
  monadicIO $ do
    xs <-
      run $ do
        marr <- thaw arr
        mbarr' <- mapConcurrently (atomicModifyIntArray marr ix . const) barr
        x <- A.read' marr ix
        pure (x : maybe (error "atomicModifyIntArray returned Nothing") toList (sequenceA mbarr'))
    return (L.sort (index' arr ix : toList barr) === L.sort xs)



prop_atomicReadIntArrayMany :: Array P Ix2 Int -> Array B Ix1 Ix2 -> Property
prop_atomicReadIntArrayMany arr bix = monadicIO $ do
  run $ do
      marr <- thaw arr
      as :: Array N Ix1 (Maybe Int) <- forM bix (A.read marr)
      as' <- forM bix (atomicReadIntArray marr)
      pure (as === as')


prop_atomicWriteIntArrayMany :: Array P Ix2 Int -> Array B Ix1 Ix2 -> (Fun Ix2 Int) -> Property
prop_atomicWriteIntArrayMany arr bix f = monadicIO $ do
  run $ do
      marr <- thaw arr
      marr' <- unsafeThaw arr
      bs :: Array N Ix1 Bool <- forM bix (\ix -> write marr ix (apply f ix))
      bs' <- forM bix (\ix -> atomicWriteIntArray marr' ix (apply f ix))
      arrRes <- unsafeFreeze (getComp arr) marr
      arrRes' <- unsafeFreeze (getComp arr) marr'
      pure (bs === bs' .&&. arrRes === arrRes')


mutableSpec ::
     ( Show r
     , Show (Array r Ix3 Int)
     , Show (Array r Ix1 Int)
     , Show (Array r Ix2 Int)
     , Eq (Array r Ix3 Int)
     , Eq (Array r Ix1 Int)
     , Eq (Array r Ix2 Int)
     , Mutable r Ix3 Int
     , Mutable r Ix1 Int
     , Mutable r Ix2 Int
     , Construct r Ix3 Int
     , Construct r Ix1 Int
     , Construct r Ix2 Int
     )
  => r
  -> SpecWith ()
mutableSpec r = do
  describe (show r) $ do
    describe "map == mapM" $ do
      it "Ix1" $ property $ prop_MapMapM r (Proxy :: Proxy Ix1)
      it "Ix2" $ property $ prop_MapMapM r (Proxy :: Proxy Ix2)
      it "Ix3" $ property $ prop_MapMapM r (Proxy :: Proxy Ix3)
    describe "imap == imapM" $ do
      it "Ix1" $ property $ prop_iMapiMapM r (Proxy :: Proxy Ix1)
      it "Ix2T" $ property $ prop_iMapiMapM r (Proxy :: Proxy Ix2)
      it "Ix3T" $ property $ prop_iMapiMapM r (Proxy :: Proxy Ix3)
    describe "makeArray == generateArrayST" $ do
      it "Ix1" $ property $ prop_generateMakeST r (Proxy :: Proxy Ix1)
      it "Ix2" $ property $ prop_generateMakeST r (Proxy :: Proxy Ix2)
      it "Ix3" $ property $ prop_generateMakeST r (Proxy :: Proxy Ix3)
    describe "makeArray == generateArrayIO" $ do
      it "Ix1" $ property $ prop_generateMakeIO r (Proxy :: Proxy Ix1)
      it "Ix2" $ property $ prop_generateMakeIO r (Proxy :: Proxy Ix2)
      it "Ix3" $ property $ prop_generateMakeIO r (Proxy :: Proxy Ix3)


generateSpec :: Spec
generateSpec = do
  mutableSpec P
  mutableSpec S
  mutableSpec U
  mutableSpec B
  mutableSpec N


spec :: Spec
spec = do
  describe "GenerateM" generateSpec
  describe "AtomicIntArraySpec" $ do
    it "atomicReadIntArrayMany" $ property $ prop_atomicReadIntArrayMany
    it "atomicWriteIntArrayMany" $ property $ prop_atomicWriteIntArrayMany
    it "atomicModifyIntArrayMany" $ property $ prop_atomicModifyIntArrayMany
