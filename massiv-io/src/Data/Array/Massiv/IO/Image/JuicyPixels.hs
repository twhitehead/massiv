{-# LANGUAGE BangPatterns          #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
-- |
-- Module      : Data.Array.Massiv.IO.Image.JuicyPixels
-- Copyright   : (c) Alexey Kuleshevich 2017
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Array.Massiv.IO.Image.JuicyPixels
  ( -- * JuicyPixels formats
    -- ** BMP
    BMP(..)
    -- ** GIF
  , GIF(..)
  , WriteOptionsGIF
  , woGetPaletteOptionsGIF
  , woSetPaletteOptionsGIF
  , JP.PaletteOptions(..)
  , JP.PaletteCreationMethod(..)
    -- *** Animated
  , WriteOptionsSequenceGIF
  , woGetGifLoopingGIFs
  , woGetPaletteOptionsGIFs
  , woSetGifLoopingGIFs
  , woSetPaletteOptionsGIFs
  , JP.GifDelay
  , JP.GifLooping(..)
  -- ** HDR
  , HDR(..)
  -- ** JPG
  , JPG(..)
  , WriteOptionsJPG
  , woGetQualityJPG
  , woSetQualityJPG
  -- ** PNG
  , PNG(..)
  -- ** TGA
  , TGA(..)
  -- ** TIF
  , TIF(..)
  -- * JuciyPixels conversion
  -- ** To JuicyPixels
  -- O(1) Conversion to JuicyPixels images
  , toAnyCS
  , decodeEither
  , toJPImageY8
  , toJPImageYA8
  , toJPImageY16
  , toJPImageYA16
  , toJPImageYF
  , toJPImageRGB8
  , toJPImageRGBA8
  , toJPImageRGB16
  , toJPImageRGBA16
  , toJPImageRGBF
  , toJPImageYCbCr8
  , toJPImageCMYK8
  , toJPImageCMYK16
  -- ** From JuicyPixels
  -- O(1) Conversion from JuicyPixels images
  -- , fromJPImageY8
  -- , fromJPImageYA8
  -- , fromJPImageY16
  -- , fromJPImageYA16
  -- , fromJPImageYF
  -- , fromJPImageRGB8
  -- , fromJPImageRGBA8
  -- , fromJPImageRGB16
  -- , fromJPImageRGBA16
  -- , fromJPImageRGBF
  -- , fromJPImageYCbCr8
  -- , fromJPImageCMYK8
  -- , fromJPImageCMYK16
  ) where

import           Prelude                   as P

import qualified Codec.Picture             as JP
import qualified Codec.Picture.ColorQuant  as JP
import qualified Codec.Picture.Gif         as JP
import qualified Codec.Picture.Jpg         as JP
import           Control.Monad             (join, msum)
import           Data.Array.Massiv         as M
import           Data.Array.Massiv.IO.Base
import qualified Data.ByteString           as B (ByteString)
import qualified Data.ByteString.Lazy      as BL (ByteString)
import           Data.Default              (Default (..))

import           Data.Typeable
import qualified Data.Vector.Storable      as V
import           Graphics.ColorSpace

--------------------------------------------------------------------------------
-- BMP Format ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Bitmap image with @.bmp@ extension.
data BMP = BMP deriving Show

instance FileFormat BMP where

  ext _ = ".bmp"


instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable BMP (Image r cs e) where
  encode _ _ = encodeEither BMP encodeBMP

instance (ColorSpace cs e, ToRGBA cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Auto BMP) (Image r cs e) where
  encode _ _ =
    encodeEither BMP (encodeAny encodeBMP id toPixelRGBA toPixelRGB toPixelRGBA)


instance ColorSpace cs e => Readable BMP (Image S cs e) where
  decode _ _ bs = JP.decodeBitmap bs >>= decodeEither showJP fromDynamicImage


instance ColorSpace cs e => Readable (Auto BMP) (Image S cs e) where
  decode _ _ bs = JP.decodeBitmap bs >>= decodeEither showJP fromAnyDynamicImage


encodeBMP :: forall r cs e . (ColorSpace cs e, Source r DIM2 (Pixel cs e))
          => Image r cs e -> Maybe BL.ByteString
encodeBMP img =
  msum
    [ do Refl <- eqT :: Maybe (cs :~: Y)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeBitmap $ toJPImageY8 img
           , return $ JP.encodeBitmap $ toJPImageY8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGB)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeBitmap $ toJPImageRGB8 img
           , return $ JP.encodeBitmap $ toJPImageRGB8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGBA)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeBitmap $ toJPImageRGBA8 img
           , return $ JP.encodeBitmap $ toJPImageRGBA8 $ M.map toWord8 img
           ]
    ]


--------------------------------------------------------------------------------
-- PNG Format ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Portable Network Graphics image with @.png@ extension.
data PNG = PNG deriving Show

instance FileFormat PNG where

  ext _ = ".png"

instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable PNG (Image r cs e) where
  encode _ _ = encodeEither PNG encodePNG


instance (ColorSpace cs e, ToYA cs e, ToRGBA cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Auto PNG) (Image r cs e) where
  encode _ _ =
    encodeEither PNG (encodeAny encodePNG id toPixelYA toPixelRGB toPixelRGBA)


instance ColorSpace cs e => Readable PNG (Image S cs e) where
  decode _ _ bs = JP.decodePng bs >>= decodeEither showJP fromDynamicImage

instance ColorSpace cs e => Readable (Auto PNG) (Image S cs e) where
  decode _ _ bs = JP.decodePng bs >>= decodeEither showJP fromAnyDynamicImage




encodePNG :: forall r cs e. (ColorSpace cs e, Source r DIM2 (Pixel cs e))
          => Image r cs e -> Maybe BL.ByteString
encodePNG img =
  msum
    [ do Refl <- eqT :: Maybe (cs :~: Y)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodePng $ toJPImageY8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodePng $ toJPImageY16 img
           , return $ JP.encodePng $ toJPImageY16 $ M.map toWord16 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: YA)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodePng $ toJPImageYA8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodePng $ toJPImageYA16 img
           , return $ JP.encodePng $ toJPImageYA16 $ M.map toWord16 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGB)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodePng $ toJPImageRGB8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodePng $ toJPImageRGB16 img
           , return $ JP.encodePng $ toJPImageRGB16 $ M.map toWord16 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGBA)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodePng $ toJPImageRGBA8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodePng $ toJPImageRGBA16 img
           , return $ JP.encodePng $ toJPImageRGBA16 $ M.map toWord16 img
           ]
    ]



--------------------------------------------------------------------------------
-- GIF Format ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Graphics Interchange Format image with @.gif@ extension.
data GIF = GIF deriving Show

newtype WriteOptionsGIF = WriteOptionsGIF
  { woGetPaletteOptionsGIF :: JP.PaletteOptions
  }

woSetPaletteOptionsGIF :: JP.PaletteOptions -> WriteOptionsGIF -> WriteOptionsGIF
woSetPaletteOptionsGIF palOpts opts = opts { woGetPaletteOptionsGIF = palOpts }

instance Default WriteOptionsGIF where
  def = WriteOptionsGIF JP.defaultPaletteOptions

instance FileFormat GIF where
  type WriteOptions GIF = WriteOptionsGIF

  ext _ = ".gif"


data WriteOptionsSequenceGIF = WriteOptionsSequenceGIF
  { woGetPaletteOptionsGIFs :: JP.PaletteOptions
  , woGetGifLoopingGIFs :: JP.GifLooping
  }

woSetPaletteOptionsGIFs :: JP.PaletteOptions -> WriteOptionsSequenceGIF -> WriteOptionsSequenceGIF
woSetPaletteOptionsGIFs palOpts opts = opts { woGetPaletteOptionsGIFs = palOpts }


woSetGifLoopingGIFs :: JP.GifLooping -> WriteOptionsSequenceGIF -> WriteOptionsSequenceGIF
woSetGifLoopingGIFs looping opts = opts { woGetGifLoopingGIFs = looping }


instance Default WriteOptionsSequenceGIF where
  def = WriteOptionsSequenceGIF JP.defaultPaletteOptions JP.LoopingNever

instance FileFormat (Sequence GIF) where

  type WriteOptions (Sequence GIF) = WriteOptionsSequenceGIF
  ext _ = ext GIF


instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable GIF (Image r cs e) where
  encode _ opt = encodeGIF opt

instance (ColorSpace cs e, ToRGB cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Auto GIF) (Image r cs e) where
  encode _ opt =
    join . encodeEither GIF (encodeAny (return . encodeGIF opt) toPixelRGB id toPixelRGB toPixelRGB)


instance ColorSpace cs e => Readable GIF (Image S cs e) where
  decode _ _ bs = JP.decodeGif bs >>= decodeEither showJP fromDynamicImage

instance ColorSpace cs e => Readable (Auto GIF) (Image S cs e) where
  decode _ _ bs = JP.decodeGif bs >>= decodeEither showJP fromAnyDynamicImage




instance ColorSpace cs e =>
         Readable (Sequence GIF) (Array B DIM1 (Image S cs e)) where
  decode _ _ bs = decodeGIFs fromDynamicImage bs



instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Sequence GIF) (Array B DIM1 (JP.GifDelay, Image r cs e)) where
  encode _ opts = encodeGIFs opts


instance ColorSpace cs e =>
         Readable (Sequence GIF) (Array B DIM1 (JP.GifDelay, Image S cs e)) where
  decode _ _ bs = decodeGIFsWithDelays fromDynamicImage bs



-- Animated GIF Format frames reading into a list

decodeGIFs :: (JP.DynamicImage -> Maybe (Image S cs e))
           -> B.ByteString -> Either String (Array B DIM1 (Image S cs e))
decodeGIFs decoder bs = do
  jpImgsLs <- JP.decodeGifImages bs
  case sequence $ fmap decoder jpImgsLs of
    Nothing     -> Left $ "Could not do an appropriate conversion"
    Just imgsLs -> Right $ fromListS1D imgsLs
{-# INLINE decodeGIFs #-}

decodeGIFsWithDelays :: (JP.DynamicImage -> Maybe (Image S cs e))
           -> B.ByteString -> Either String (Array B DIM1 (JP.GifDelay, Image S cs e))
decodeGIFsWithDelays decoder bs = do
  jpImgsLs <- JP.decodeGifImages bs
  delays <- JP.getDelaysGifImages bs
  case sequence $ fmap decoder jpImgsLs of
    Nothing     -> Left $ "Could not do an appropriate conversion"
    Just imgsLs -> Right $ fromListS1D $ P.zip delays imgsLs
{-# INLINE decodeGIFsWithDelays #-}



encodeGIF :: forall r cs e . (ColorSpace cs e, Source r DIM2 (Pixel cs e))
          => WriteOptionsGIF
          -> Image r cs e
          -> Either String BL.ByteString
encodeGIF (WriteOptionsGIF pal) img =
  msum
    [ maybe encodeErr Right $ do
        Refl <- eqT :: Maybe (cs :~: Y)
        msum
          [ do Refl <- eqT :: Maybe (e :~: Word8)
               return $ JP.encodeGifImage $ toJPImageY8 img
          , return $ JP.encodeGifImage $ toJPImageY8 $ M.map toWord8 img
          ]
    , do palImg <-
           maybe encodeErr Right $ do
             Refl <- eqT :: Maybe (cs :~: RGB)
             msum
               [ do Refl <- eqT :: Maybe (e :~: Word8)
                    palettizeRGB pal img
               , palettizeRGB pal $ M.map toWord8 img
               ]
         uncurry JP.encodeGifImageWithPalette palImg
    ]
  where
    encodeErr = Left "Could not encode GIF"
{-# INLINE encodeGIF #-}



encodeGIFs :: forall r cs e . (ColorSpace cs e, Source r DIM2 (Pixel cs e))
           => WriteOptionsSequenceGIF
           -> Array B DIM1 (JP.GifDelay, Image r cs e)
           -> Either String BL.ByteString
encodeGIFs (WriteOptionsSequenceGIF pal looping) arr =
  msum
    [ do palImgsLs <-
           maybe encodeErr Right $
           msum
             [ do Refl <- eqT :: Maybe (cs :~: Y)
                  msum
                    [ do Refl <- eqT :: Maybe (e :~: Word8)
                         return $
                           P.map
                             ((flip (,) JP.greyPalette) . toJPImageY8)
                             imgsLs
                    , return $
                      P.map
                        ((flip (,) JP.greyPalette) . toJPImageY8 . M.map toWord8)
                        imgsLs
                    ]
             , do Refl <- eqT :: Maybe (cs :~: RGB)
                  msum
                    [ do Refl <- eqT :: Maybe (e :~: Word8)
                         P.mapM (palettizeRGB pal) imgsLs
                    , P.mapM (palettizeRGB pal . M.map toWord8) imgsLs
                    ]
             ]
         let palDelImgsLs =
               P.zipWith (\(i, p) d -> (p, d, i)) palImgsLs delaysLs
         JP.encodeGifImages looping palDelImgsLs
    ]
  where
    encodeErr = Left "Could not encode GIF"
    delaysLs = toListS1D delays
    imgsLs = toListS1D imgs
    (delays, imgs) = M.unzip arr
{-# INLINE encodeGIFs #-}


palettizeRGB :: forall r e . (ColorSpace RGB e, Source r DIM2 (Pixel RGB e))
          => JP.PaletteOptions
          -> Image r RGB e
          -> Maybe (JP.Image JP.Pixel8, JP.Palette)
palettizeRGB pal img = do
  msum
    [ do Refl <- eqT :: Maybe (e :~: Word8)
         return $ palettize' img
    , return $ palettize' $ M.map toWord8 img
    ]
  where
    palettize' :: forall r' . Source r' DIM2 (Pixel RGB Word8) =>
                  Image r' RGB Word8 -> (JP.Image JP.Pixel8, JP.Palette)
    palettize' = JP.palettize pal . toJPImageRGB8
    {-# INLINE palettize' #-}
{-# INLINE palettizeRGB #-}


--------------------------------------------------------------------------------
-- HDR Format ------------------------------------------------------------------
--------------------------------------------------------------------------------


-- | High-dynamic-range image with @.hdr@ or @.pic@ extension.
data HDR = HDR deriving Show

instance FileFormat HDR where

  ext _ = ".hdr"

  exts _ = [".hdr", ".pic"]

instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable HDR (Image r cs e) where
  encode _ _ =
    encodeEither HDR encodeHDR


instance (ColorSpace cs e, ToRGB cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Auto HDR) (Image r cs e) where
  encode _ _ =
    encodeEither HDR (encodeAny encodeHDR toPixelRGB toPixelRGB toPixelRGB toPixelRGB)


instance ColorSpace cs e => Readable HDR (Image S cs e) where
  decode _ _ bs = JP.decodePng bs >>= decodeEither showJP fromDynamicImage

instance ColorSpace cs e => Readable (Auto HDR) (Image S cs e) where
  decode _ _ bs = JP.decodePng bs >>= decodeEither showJP fromAnyDynamicImage




encodeHDR :: forall r cs e. (ColorSpace cs e, Source r DIM2 (Pixel cs e))
          => Image r cs e -> Maybe BL.ByteString
encodeHDR img = do
  Refl <- eqT :: Maybe (cs :~: RGB)
  msum
    [ do Refl <- eqT :: Maybe (e :~: Float)
         return $ JP.encodeHDR $ toJPImageRGBF img
    , return $ JP.encodeHDR $ toJPImageRGBF $ M.map toFloat img
    ]




--------------------------------------------------------------------------------
-- JPG Format ------------------------------------------------------------------
--------------------------------------------------------------------------------

newtype WriteOptionsJPG = WriteOptionsJPG { woGetQualityJPG :: Word8 } deriving Show

-- | Set the image quality, supplied value will be clamped to @[0, 100]@
-- range. This setting directly affects the Jpeg compression level.
woSetQualityJPG :: Word8 -> WriteOptionsJPG -> WriteOptionsJPG
woSetQualityJPG q opts = opts { woGetQualityJPG = min 100 (max 0 q) }

instance Default WriteOptionsJPG where
  def = WriteOptionsJPG 100

-- | Joint Photographic Experts Group image with @.jpg@ or @.jpeg@ extension.
data JPG = JPG deriving Show

instance FileFormat JPG where
  type WriteOptions JPG = WriteOptionsJPG

  ext _ = ".jpg"

  exts _ = [".jpg", ".jpeg"]

instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable JPG (Image r cs e) where
  encode _ opts = encodeEither JPG (encodeJPG opts)


instance (ColorSpace cs e, ToYCbCr cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Auto JPG) (Image r cs e) where
  encode _ opts =
    encodeEither JPG (encodeAny (encodeJPG opts) toPixelYCbCr toPixelYCbCr toPixelYCbCr toPixelYCbCr)


instance ColorSpace cs e => Readable JPG (Image S cs e) where
  decode _ _ bs = JP.decodeJpeg bs >>= decodeEither showJP fromDynamicImage

instance ColorSpace cs e => Readable (Auto JPG) (Image S cs e) where
  decode _ _ bs = JP.decodeJpeg bs >>= decodeEither showJP fromAnyDynamicImage




encodeJPG :: forall r cs e. (ColorSpace cs e, Source r DIM2 (Pixel cs e))
          => WriteOptionsJPG -> Image r cs e -> Maybe BL.ByteString
encodeJPG (WriteOptionsJPG q) img =
  msum
    [ do Refl <- eqT :: Maybe (cs :~: Y)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ encJPG $ toJPImageY8 img
           , return $ encJPG $ toJPImageY8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGB)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ encJPG $ toJPImageRGB8 img
           , return $ encJPG $ toJPImageRGB8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: CMYK)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ encJPG $ toJPImageCMYK8 img
           , return $ encJPG $ toJPImageCMYK8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: YCbCr)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ encJPG $ toJPImageYCbCr8 img
           , return $ encJPG $ toJPImageYCbCr8 $ M.map toWord8 img
           ]
    ]
  where
    encJPG :: forall px . JP.JpgEncodable px => JP.Image px -> BL.ByteString
    encJPG = JP.encodeDirectJpegAtQualityWithMetadata q mempty
    {-# INLINE encJPG #-}



--------------------------------------------------------------------------------
-- TGA Format ------------------------------------------------------------------
--------------------------------------------------------------------------------


-- | Truevision Graphics Adapter image with .tga extension.
data TGA = TGA

instance FileFormat TGA where

  ext _ = ".tga"
  {-# INLINE ext #-}



instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable TGA (Image r cs e) where
  encode _ _ = encodeEither TGA encodeTGA

instance (ColorSpace cs e, ToRGBA cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Auto TGA) (Image r cs e) where
  encode _ _ =
    encodeEither TGA (encodeAny encodeTGA id toPixelRGBA toPixelRGB toPixelRGBA)


instance ColorSpace cs e => Readable TGA (Image S cs e) where
  decode _ _ bs = JP.decodeTga bs >>= decodeEither showJP fromDynamicImage


instance ColorSpace cs e => Readable (Auto TGA) (Image S cs e) where
  decode _ _ bs = JP.decodeTga bs >>= decodeEither showJP fromAnyDynamicImage


encodeTGA :: forall r cs e . (ColorSpace cs e, Source r DIM2 (Pixel cs e))
          => Image r cs e -> Maybe BL.ByteString
encodeTGA img =
  msum
    [ do Refl <- eqT :: Maybe (cs :~: Y)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTga $ toJPImageY8 img
           , return $ JP.encodeTga $ toJPImageY8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGB)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTga $ toJPImageRGB8 img
           , return $ JP.encodeTga $ toJPImageRGB8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGBA)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTga $ toJPImageRGBA8 img
           , return $ JP.encodeTga $ toJPImageRGBA8 $ M.map toWord8 img
           ]
    ]


--------------------------------------------------------------------------------
-- TIF Format ------------------------------------------------------------------
--------------------------------------------------------------------------------


-- | Tagged Image File Format image with @.tif@ or @.tiff@ extension.
data TIF = TIF deriving Show

instance FileFormat TIF where

  ext _ = ".tif"
  {-# INLINE ext #-}

  exts _ = [".tif", ".tiff"]
  {-# INLINE exts #-}


instance (ColorSpace cs e, Source r DIM2 (Pixel cs e)) =>
         Writable TIF (Image r cs e) where
  encode _ _ = encodeEither TIF encodeTIF


instance (ColorSpace cs e, ToRGBA cs e, Source r DIM2 (Pixel cs e)) =>
         Writable (Auto TIF) (Image r cs e) where
  encode _ _ = encodeEither TIF (encodeAny encodeTIF id id id toPixelRGBA)


instance ColorSpace cs e => Readable TIF (Image S cs e) where
  decode _ _ bs = JP.decodeTiff bs >>= decodeEither showJP fromDynamicImage

instance ColorSpace cs e => Readable (Auto TIF) (Image S cs e) where
  decode _ _ bs = JP.decodeTiff bs >>= decodeEither showJP fromAnyDynamicImage




encodeTIF :: forall r cs e. (ColorSpace cs e, Source r DIM2 (Pixel cs e))
          => Image r cs e -> Maybe BL.ByteString
encodeTIF img =
  msum
    [ do Refl <- eqT :: Maybe (cs :~: Y)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTiff $ toJPImageY8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodeTiff $ toJPImageY16 img
           , return $ JP.encodeTiff $ toJPImageY16 $ M.map toWord16 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: YA)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTiff $ toJPImageYA8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodeTiff $ toJPImageYA16 img
           , return $ JP.encodeTiff $ toJPImageYA16 $ M.map toWord16 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGB)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTiff $ toJPImageRGB8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodeTiff $ toJPImageRGB16 img
           , return $ JP.encodeTiff $ toJPImageRGB16 $ M.map toWord16 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: RGBA)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTiff $ toJPImageRGBA8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodeTiff $ toJPImageRGBA16 img
           , return $ JP.encodeTiff $ toJPImageRGBA16 $ M.map toWord16 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: YCbCr)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTiff $ toJPImageYCbCr8 img
           , return $ JP.encodeTiff $ toJPImageYCbCr8 $ M.map toWord8 img
           ]
    , do Refl <- eqT :: Maybe (cs :~: CMYK)
         msum
           [ do Refl <- eqT :: Maybe (e :~: Word8)
                return $ JP.encodeTiff $ toJPImageCMYK8 img
           , do Refl <- eqT :: Maybe (e :~: Word16)
                return $ JP.encodeTiff $ toJPImageCMYK16 img
           , return $ JP.encodeTiff $ toJPImageCMYK16 $ M.map toWord16 img
           ]
    ]




--------------------------------------------------------------------------------
-- Common encoding/decoding functions ------------------------------------------
--------------------------------------------------------------------------------


encodeAny
  :: forall r cs e a csY eY csYA eYA csC eC csCA eCA.
     ( ColorSpace cs e
     , ColorSpace csC eC
     , ColorSpace csCA eCA
     , ColorSpace csY eY
     , ColorSpace csYA eYA
     , Source r DIM2 (Pixel cs e)
     )
  => (forall r' cs' e'. (Source r' DIM2 (Pixel cs' e'), ColorSpace cs' e') =>
                          Image r' cs' e' -> Maybe a)
  -> (Pixel cs e -> Pixel csY eY) -- ^ To preferred from Luma
  -> (Pixel cs e -> Pixel csYA eYA) -- ^ To preferred from Luma with Alpha
  -> (Pixel cs e -> Pixel csC eC) -- ^ To preferred from any color
  -> (Pixel cs e -> Pixel csCA eCA) -- ^ To preferred from any color with Alpha
  -> Image r cs e
  -> Maybe a
encodeAny enc toLuma toLumaA toColor toColorA img =
  msum
    [ enc img
    , do Refl <- eqT :: Maybe (cs :~: Y)
         enc $ M.map toLuma img
    , do Refl <- eqT :: Maybe (cs :~: YA)
         enc $ M.map toLumaA img
    , do Refl <- eqT :: Maybe (cs :~: RGB)
         enc $ M.map toColor img
    , do Refl <- eqT :: Maybe (cs :~: RGBA)
         enc $ M.map toColorA img
    , do Refl <- eqT :: Maybe (cs :~: HSI)
         enc $ M.map toColor img
    , do Refl <- eqT :: Maybe (cs :~: HSIA)
         enc $ M.map toColorA img
    , do Refl <- eqT :: Maybe (cs :~: YCbCr)
         enc $ M.map toColor img
    , do Refl <- eqT :: Maybe (cs :~: YCbCrA)
         enc $ M.map toColorA img
    , do Refl <- eqT :: Maybe (cs :~: CMYK)
         enc $ M.map toColor img
    , do Refl <- eqT :: Maybe (cs :~: CMYKA)
         enc $ M.map toColorA img
    , do Refl <- eqT :: Maybe (Pixel cs e :~: Pixel X Bit)
         enc $ M.map fromPixelBinary img
    ]




elevate
  :: forall cs e' e.
     ( Functor (Pixel cs)
     , ColorSpace cs e'
     , ColorSpace cs e
     , Source D DIM2 (Pixel cs e')
     )
  => Image D cs e' -> Maybe (Image D cs e)
elevate img =
  msum
    [ fmap (\Refl -> img) (eqT :: Maybe (e :~: e'))
    , do Refl <- eqT :: Maybe (e :~: Word8)
         return $ M.map toWord8 img
    , do Refl <- eqT :: Maybe (e :~: Word16)
         return $ M.map toWord16 img
    , do Refl <- eqT :: Maybe (e :~: Word32)
         return $ M.map toWord32 img
    , do Refl <- eqT :: Maybe (e :~: Word64)
         return $ M.map toWord64 img
    , do Refl <- eqT :: Maybe (e :~: Double)
         return $ M.map toDouble img
    ]

fromDynamicImage :: forall cs e . (ColorSpace cs e, Source S DIM2 (Pixel cs e))
                 => JP.DynamicImage -> Maybe (Image S cs e)
fromDynamicImage jpDynImg =
  case jpDynImg of
    JP.ImageY8 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel Y Word8)
      fromJPImageUnsafe jimg
    JP.ImageY16 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel Y Word16)
      fromJPImageUnsafe jimg
    JP.ImageYF jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel Y Float)
      fromJPImageUnsafe jimg
    JP.ImageYA8 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel YA Word8)
      fromJPImageUnsafe jimg
    JP.ImageYA16 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel YA Word16)
      fromJPImageUnsafe jimg
    JP.ImageRGB8 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel RGB Word8)
      fromJPImageUnsafe jimg
    JP.ImageRGB16 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel RGB Word16)
      fromJPImageUnsafe jimg
    JP.ImageRGBF jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel RGB Float)
      fromJPImageUnsafe jimg
    JP.ImageRGBA8 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel RGBA Word8)
      fromJPImageUnsafe jimg
    JP.ImageRGBA16 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel RGBA Word16)
      fromJPImageUnsafe jimg
    JP.ImageYCbCr8 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel YCbCr Word8)
      fromJPImageUnsafe jimg
    JP.ImageCMYK8 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel CMYK Word8)
      fromJPImageUnsafe jimg
    JP.ImageCMYK16 jimg -> do
      Refl <- eqT :: Maybe (Pixel cs e :~: Pixel CMYK Word16)
      fromJPImageUnsafe jimg



fromAnyDynamicImage :: ColorSpace cs e => JP.DynamicImage -> Maybe (Image S cs e)
fromAnyDynamicImage jpDynImg = do
  case jpDynImg of
    JP.ImageY8 jimg     -> (fromJPImageUnsafe jimg :: Maybe (Image S Y Word8))     >>= toAnyCS
    JP.ImageY16 jimg    -> (fromJPImageUnsafe jimg :: Maybe (Image S Y Word16))    >>= toAnyCS
    JP.ImageYF jimg     -> (fromJPImageUnsafe jimg :: Maybe (Image S Y Float))     >>= toAnyCS
    JP.ImageYA8 jimg    -> (fromJPImageUnsafe jimg :: Maybe (Image S YA Word8))    >>= toAnyCS
    JP.ImageYA16 jimg   -> (fromJPImageUnsafe jimg :: Maybe (Image S YA Word16))   >>= toAnyCS
    JP.ImageRGB8 jimg   -> (fromJPImageUnsafe jimg :: Maybe (Image S RGB Word8))   >>= toAnyCS
    JP.ImageRGB16 jimg  -> (fromJPImageUnsafe jimg :: Maybe (Image S RGB Word16))  >>= toAnyCS
    JP.ImageRGBF jimg   -> (fromJPImageUnsafe jimg :: Maybe (Image S RGB Float))   >>= toAnyCS
    JP.ImageRGBA8 jimg  -> (fromJPImageUnsafe jimg :: Maybe (Image S RGBA Word8))  >>= toAnyCS
    JP.ImageRGBA16 jimg -> (fromJPImageUnsafe jimg :: Maybe (Image S RGBA Word16)) >>= toAnyCS
    JP.ImageYCbCr8 jimg -> (fromJPImageUnsafe jimg :: Maybe (Image S YCbCr Word8)) >>= toAnyCS
    JP.ImageCMYK8 jimg  -> (fromJPImageUnsafe jimg :: Maybe (Image S CMYK Word8))  >>= toAnyCS
    JP.ImageCMYK16 jimg -> (fromJPImageUnsafe jimg :: Maybe (Image S CMYK Word16)) >>= toAnyCS



toAnyCS
  :: forall r cs' e' cs e.
     ( Source r DIM2 (Pixel cs' e')
     , Storable (Pixel cs e)
     , ColorSpace cs e
     , ToYA cs' e'
     , ToRGBA cs' e'
     , ToHSIA cs' e'
     , ToCMYKA cs' e'
     , ToYCbCrA cs' e'
     )
  => Image r cs' e' -> Maybe (Image S cs e)
toAnyCS img =
  msum
    [ fmap (\Refl -> computeSource img) (eqT :: Maybe (Pixel cs' e' :~: Pixel cs e))
    , msum
        [ do Refl <- eqT :: Maybe (cs :~: Y)
             compute <$> elevate (M.map toPixelY img)
        , do Refl <- eqT :: Maybe (cs :~: YA)
             compute <$> elevate (M.map toPixelYA img)
        , do Refl <- eqT :: Maybe (cs :~: RGB)
             compute <$> elevate (M.map toPixelRGB img)
        , do Refl <- eqT :: Maybe (cs :~: RGBA)
             compute <$> elevate (M.map toPixelRGBA img)
        , do Refl <- eqT :: Maybe (cs :~: HSI)
             compute <$> elevate (M.map toPixelHSI img)
        , do Refl <- eqT :: Maybe (cs :~: HSIA)
             compute <$> elevate (M.map toPixelHSIA img)
        , do Refl <- eqT :: Maybe (cs :~: CMYK)
             compute <$> elevate (M.map toPixelCMYK img)
        , do Refl <- eqT :: Maybe (cs :~: CMYKA)
             compute <$> elevate (M.map toPixelCMYKA img)
        , do Refl <- eqT :: Maybe (cs :~: YCbCr)
             compute <$> elevate (M.map toPixelYCbCr img)
        , do Refl <- eqT :: Maybe (cs :~: YCbCrA)
             compute <$> elevate (M.map toPixelYCbCrA img)
        , do Refl <- eqT :: Maybe (Pixel cs e :~: Pixel X Bit)
             return $ compute $ M.map toPixelBinary img
        ]
    ]


encodeEither
  :: forall f r cs e bs. (ColorSpace cs e, FileFormat f, Typeable f)
  => f -> (Image r cs e -> Maybe bs) -> Image r cs e -> Either String bs
encodeEither f enc img =
  case enc img of
    Nothing ->
      Left $
      "Format " ++
      showsTypeRep (typeOf f) " cannot be encoded as (" ++
      showsTypeRep (typeRep (Proxy :: Proxy cs)) " " ++
      showsTypeRep (typeRep (Proxy :: Proxy e)) ")"
    Just bs -> Right bs

-- decodeEither :: forall cs e. ColorSpace cs e =>
--                 (JP.DynamicImage -> Maybe (Image S cs e))
--              -> JP.DynamicImage
--              -> Either String (Image S cs e)
-- decodeEither conv jpDynImg =
--   maybe
--     (Left $
--      "Cannot decode image: <" ++
--      jpImageShowCS jpDynImg ++
--      "> into " ++
--      "<Image S " ++
--      showsTypeRep (typeRep (Proxy :: Proxy cs)) " " ++
--      showsTypeRep (typeRep (Proxy :: Proxy e)) ">")
--     Right
--     (conv jpDynImg)


decodeEither :: forall cs e a. ColorSpace cs e =>
                (a -> String)
             -> (a -> Maybe (Image S cs e))
             -> a
             -> Either String (Image S cs e)
decodeEither showCS conv eImg =
  maybe
    (Left $
     "Cannot decode image: <" ++
     showCS eImg ++
     "> into " ++
     "<Image S " ++
     showsTypeRep (typeRep (Proxy :: Proxy cs)) " " ++
     showsTypeRep (typeRep (Proxy :: Proxy e)) ">")
    Right
    (conv eImg)


showJP :: JP.DynamicImage -> String
showJP (JP.ImageY8     _) = "Image S Y Word8"
showJP (JP.ImageY16    _) = "Image S Y Word16"
showJP (JP.ImageYF     _) = "Image S Y Float"
showJP (JP.ImageYA8    _) = "Image S YA Word8"
showJP (JP.ImageYA16   _) = "Image S YA Word16"
showJP (JP.ImageRGB8   _) = "Image S RGB Word8"
showJP (JP.ImageRGB16  _) = "Image S RGB Word16"
showJP (JP.ImageRGBF   _) = "Image S RGB Float"
showJP (JP.ImageRGBA8  _) = "Image S RGBA Word8"
showJP (JP.ImageRGBA16 _) = "Image S RGBA Word16"
showJP (JP.ImageYCbCr8 _) = "Image S YCbCr Word8"
showJP (JP.ImageCMYK8  _) = "Image S CMYK Word8"
showJP (JP.ImageCMYK16 _) = "Image S CMYK Word16"


-- Encoding

-- | TODO: Validate size
toJPImageUnsafe
  :: forall r cs a . (JP.Pixel a, Source r DIM2 (Pixel cs (JP.PixelBaseComponent a)),
                      ColorSpace cs (JP.PixelBaseComponent a),
                      Storable (Pixel cs (JP.PixelBaseComponent a)))
  => Image r cs (JP.PixelBaseComponent a)
  -> JP.Image a
toJPImageUnsafe img = JP.Image n m $ V.unsafeCast $ toVector' arrS where
  !arrS = computeSource img :: Image S cs (JP.PixelBaseComponent a)
  (m, n) = size img
{-# INLINE toJPImageUnsafe #-}

toJPImageY8 :: Source r DIM2 (Pixel Y Word8) => Image r Y Word8 -> JP.Image JP.Pixel8
toJPImageY8 = toJPImageUnsafe
{-# INLINE toJPImageY8 #-}

toJPImageY16 :: Source r DIM2 (Pixel Y Word16) => Image r Y Word16 -> JP.Image JP.Pixel16
toJPImageY16 = toJPImageUnsafe
{-# INLINE toJPImageY16 #-}

toJPImageYA8 :: Source r DIM2 (Pixel YA Word8) => Image r YA Word8 -> JP.Image JP.PixelYA8
toJPImageYA8 = toJPImageUnsafe
{-# INLINE toJPImageYA8 #-}

toJPImageYA16 :: Source r DIM2 (Pixel YA Word16) => Image r YA Word16 -> JP.Image JP.PixelYA16
toJPImageYA16 = toJPImageUnsafe
{-# INLINE toJPImageYA16 #-}

toJPImageYF :: Source r DIM2 (Pixel Y Float) => Image r Y Float -> JP.Image JP.PixelF
toJPImageYF = toJPImageUnsafe
{-# INLINE toJPImageYF #-}

toJPImageRGB8 :: Source r DIM2 (Pixel RGB Word8) => Image r RGB Word8 -> JP.Image JP.PixelRGB8
toJPImageRGB8 = toJPImageUnsafe
{-# INLINE toJPImageRGB8 #-}

toJPImageRGBA8 :: Source r DIM2 (Pixel RGBA Word8) => Image r RGBA Word8 -> JP.Image JP.PixelRGBA8
toJPImageRGBA8 = toJPImageUnsafe
{-# INLINE toJPImageRGBA8 #-}

toJPImageRGB16 :: Source r DIM2 (Pixel RGB Word16) => Image r RGB Word16 -> JP.Image JP.PixelRGB16
toJPImageRGB16 = toJPImageUnsafe
{-# INLINE toJPImageRGB16 #-}

toJPImageRGBA16 :: Source r DIM2 (Pixel RGBA Word16) => Image r RGBA Word16 -> JP.Image JP.PixelRGBA16
toJPImageRGBA16 = toJPImageUnsafe
{-# INLINE toJPImageRGBA16 #-}

toJPImageRGBF :: Source r DIM2 (Pixel RGB Float) => Image r RGB Float -> JP.Image JP.PixelRGBF
toJPImageRGBF = toJPImageUnsafe
{-# INLINE toJPImageRGBF #-}

toJPImageYCbCr8 :: Source r DIM2 (Pixel YCbCr Word8) => Image r YCbCr Word8 -> JP.Image JP.PixelYCbCr8
toJPImageYCbCr8 = toJPImageUnsafe
{-# INLINE toJPImageYCbCr8 #-}

toJPImageCMYK8 :: Source r DIM2 (Pixel CMYK Word8) => Image r CMYK Word8 -> JP.Image JP.PixelCMYK8
toJPImageCMYK8 = toJPImageUnsafe
{-# INLINE toJPImageCMYK8 #-}

toJPImageCMYK16 :: Source r DIM2 (Pixel CMYK Word16) => Image r CMYK Word16 -> JP.Image JP.PixelCMYK16
toJPImageCMYK16 = toJPImageUnsafe
{-# INLINE toJPImageCMYK16 #-}




-- General decoding and helper functions

-- | TODO: Validate size
fromJPImageUnsafe :: (Storable (Pixel cs e), JP.Pixel jpx) =>
                     JP.Image jpx -> Maybe (Image S cs e)
fromJPImageUnsafe (JP.Image n m !v) = fromVector (m, n) $ V.unsafeCast v
{-# INLINE fromJPImageUnsafe #-}

