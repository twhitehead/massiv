{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances  #-}
-- |
-- Module      : Data.Array.Massiv.IO.Image
-- Copyright   : (c) Alexey Kuleshevich 2017
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Array.Massiv.IO.Image
  ( Encode
  , encodeImage
  , imageWriteFormats
  , imageWriteAutoFormats
  , Decode
  , decodeImage
  , imageReadFormats
  , imageReadAutoFormats
  , module Data.Array.Massiv.IO.Image.JuicyPixels
  , module Data.Array.Massiv.IO.Image.Netpbm
  ) where

import           Data.Array.Massiv
import           Data.Array.Massiv.IO.Base
import           Data.Array.Massiv.IO.Image.JuicyPixels
import           Data.Array.Massiv.IO.Image.Netpbm
import qualified Data.ByteString                        as B (ByteString)
import qualified Data.ByteString.Lazy                   as BL (ByteString)
import           Data.Char                              (toLower)
import           Graphics.ColorSpace
import           Prelude                                as P
import           System.FilePath                        (takeExtension)



data Encode out where
  EncodeAs :: (FileFormat f, Writable f out) => f -> Encode out


instance FileFormat (Encode (Image r cs e)) where
  ext (EncodeAs f) = ext f

instance Writable (Encode (Image r cs e)) (Image r cs e) where
  encode (EncodeAs f) _ = encode f (defaultWriteOptions f)


encodeImage
  :: (Source r DIM2 (Pixel cs e), ColorSpace cs e)
  => [Encode (Image r cs e)]
  -> FilePath
  -> (Image r cs e)
  -> Either String BL.ByteString
encodeImage formats path img = do
  let ext' = P.map toLower . takeExtension $ path
  case dropWhile (not . isFormat ext') formats of
    [] -> Left $ "File format is not supported: " ++ ext'
    (f:_) -> encode f () img


imageWriteFormats :: (Source r DIM2 (Pixel cs e), ColorSpace cs e) => [Encode (Image r cs e)]
imageWriteFormats =
  [ EncodeAs BMP
  , EncodeAs GIF
  , EncodeAs HDR
  , EncodeAs JPG
  , EncodeAs PNG
  , EncodeAs TGA
  , EncodeAs TIF
  ]

imageWriteAutoFormats
  :: ( Source r DIM2 (Pixel cs e)
     , ColorSpace cs e
     , ToYA cs e
     , ToRGBA cs e
     , ToYCbCr cs e
     , ToCMYK cs e
     )
  => [Encode (Image r cs e)]
imageWriteAutoFormats =
  [ EncodeAs (Auto BMP)
  , EncodeAs (Auto GIF)
  , EncodeAs (Auto HDR)
  , EncodeAs (Auto JPG)
  , EncodeAs (Auto PNG)
  , EncodeAs (Auto TGA)
  , EncodeAs (Auto TIF)
  ]



data Decode out where
  DecodeAs :: (FileFormat f, Readable f out) => f -> Decode out

instance FileFormat (Decode (Image r cs e)) where
  ext (DecodeAs f) = ext f

instance Readable (Decode (Image r cs e)) (Image r cs e) where
  decode (DecodeAs f) _ = decode f (defaultReadOptions f)


decodeImage
  :: (Source r DIM2 (Pixel cs e), ColorSpace cs e)
  => [Decode (Image r cs e)]
  -> FilePath
  -> B.ByteString
  -> Either String (Image r cs e)
decodeImage formats path bs = do
  let ext' = P.map toLower . takeExtension $ path
  case dropWhile (not . isFormat ext') formats of
    [] -> Left $ "File format is not supported: " ++ ext'
    (f:_) -> decode f () bs


imageReadFormats
  :: (Source S DIM2 (Pixel cs e), ColorSpace cs e)
  => [Decode (Image S cs e)]
imageReadFormats =
  [ DecodeAs BMP
  , DecodeAs GIF
  , DecodeAs HDR
  , DecodeAs JPG
  , DecodeAs PNG
  , DecodeAs TGA
  , DecodeAs TIF
  , DecodeAs PBM
  , DecodeAs PGM
  , DecodeAs PPM
  ]

imageReadAutoFormats
  :: (Source S DIM2 (Pixel cs e), ColorSpace cs e)
  => [Decode (Image S cs e)]
imageReadAutoFormats =
  [ DecodeAs (Auto BMP)
  , DecodeAs (Auto GIF)
  , DecodeAs (Auto HDR)
  , DecodeAs (Auto JPG)
  , DecodeAs (Auto PNG)
  , DecodeAs (Auto TGA)
  , DecodeAs (Auto TIF)
  , DecodeAs (Auto PBM)
  , DecodeAs (Auto PGM)
  , DecodeAs (Auto PPM)
  ]
