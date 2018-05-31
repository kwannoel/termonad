{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE TemplateHaskell #-}

module Termonad.FocusList where

import Termonad.Prelude

import Control.Lens
import Control.Lens.TH
import Data.Constraint ((:-)(Sub), Dict(Dict))
import Data.Constraint.Nat (plusNat)
import Data.Finite (Finite, finite, getFinite, shift, weaken)
import Data.Type.Equality ((:~:)(Refl))
import Data.Void
import GHC.TypeLits (type (+), type (<=), type (<=?), KnownNat, Nat, natVal)
import Unsafe.Coerce (unsafeCoerce)

newtype Focus = Focus
  { unFocus :: Int
  } deriving newtype (Eq, Num, Read, Show)

-- TODO: Might want to deal with having an empty focus list??

-- TODO: Probably be better
-- implemented as an Order statistic tree
-- (https://en.wikipedia.org/wiki/Order_statistic_tree).
data FocusList a = FocusList
  { focusListFocus :: {-# UNPACK #-} !Focus
  , focusListLen :: {-# UNPACK #-} !Int
  , focusList :: !(IntMap a)
  } deriving (Read, Show)

$(makeLensesFor
    [ ("focusListFocus", "lensFocusListFocus")
    , ("focusListLen", "lensFocusListLen")
    , ("focusList", "lensFocusList")
    ]
    ''FocusList
 )

lensFocusListAt :: Int -> Lens' (FocusList a) (Maybe a)
lensFocusListAt i = lensFocusList . at i

singletonFL :: a -> FocusList a
singletonFL a =
  FocusList
    { focusListFocus = 0
    , focusListLen = 1
    , focusList = singletonMap 0 a
    }

-- | This is an invariant that the 'FocusList' must always protect.
invariantFL :: FocusList a -> Bool
invariantFL fl = False

-- | Append a new value to the end of a 'FocusList'.
appendFL :: a -> FocusList a -> FocusList a
appendFL a fl = unsafeInsertNewFL (fl ^. lensFocusListLen) a fl

-- | Unsafely insert a new @a@ in a 'FocusList'.  This sets the 'Int' value to
-- @a@.  The length of the 'FocusList' will be increased by 1.  The
-- 'FocusList's 'Focus' is not changed.
--
-- If there is some value in the 'FocusList' already at the 'Int', then it will
-- be overwritten.  Also, the 'Int' is not checked to make sure it is above 0.
unsafeInsertNewFL :: Int -> a -> FocusList a -> FocusList a
unsafeInsertNewFL i a fl =
  fl &
    lensFocusListLen +~ 1 &
    lensFocusListAt i ?~ a

-- | This unsafely shifts all values up in a 'FocusList'.  It also updates the
-- 'Focus' of the 'FocusList' if it has been shifted.
--
-- It does not check that the 'Int' is greater than 0.
unsafeShiftUpFrom :: forall a. Int -> FocusList a -> FocusList a
unsafeShiftUpFrom i fl =
  let intMap = fl ^. lensFocusList
      lastElemIdx = (fl ^. lensFocusListLen) - 1
      newIntMap = go i lastElemIdx intMap
      oldFocus = fl ^. lensFocusListFocus
  in
  fl &
    lensFocusList .~ newIntMap &
    lensFocusListFocus .~ if i > lastElemIdx then oldFocus else oldFocus + 1
  where
    go :: Int -> Int -> IntMap a -> IntMap a
    go idxToInsert idxToShiftUp intMap
      | idxToInsert <= idxToShiftUp =
        let val = unsafeLookup idxToShiftUp intMap
            newMap =
              insertMap (idxToShiftUp + 1) val (deleteMap idxToShiftUp intMap)
        in go idxToInsert (idxToShiftUp - 1) newMap
      | otherwise = intMap

-- | This is an unsafe lookup function.  This assumes that the 'Int' exists in
-- the 'IntMap'.
unsafeLookup :: Int -> IntMap a -> a
unsafeLookup i intmap =
  case lookup i intmap of
    Nothing -> error $ "unsafeLookup: key " <> show i <> " not found in intmap"
    Just a -> a

insertFL :: Int -> a -> FocusList a -> Maybe (FocusList a)
insertFL i a fl =
  if i < 0 || i > (fl ^. lensFocusListLen)
    then
      -- Return Nothing if the insertion position is out of bounds.
      Nothing
    else
      -- Otherwise, shift all existing values up one and insert the new
      -- value in the opened place.
      let shiftedUpFL = unsafeShiftUpFrom i fl
      in Just $ unsafeInsertNewFL i a shiftedUpFL

-- | Remove an element from a 'FocusList'.
removeFL
  :: Int -- ^ Index of the element to remove from the 'FocusList'.
  -> FocusList a  -- ^ The 'FocusList' to remove an element from.
  -> (Focus -> FocusList a -> Focus) -- ^ An function to use to update the
                                     -- 'Focus' of the 'FocusList'.
  -> Maybe (FocusList a)
removeFL = undefined
