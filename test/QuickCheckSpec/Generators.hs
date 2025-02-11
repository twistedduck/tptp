{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE CPP #-}

-- |
-- Module       : Generators
-- Description  : QuickCheck generators for datatypes in the tptp library.
-- Copyright    : (c) Evgenii Kotelnikov, 2019-2021
-- License      : GPL-3
-- Maintainer   : evgeny.kotelnikov@gmail.com
-- Stability    : experimental
--

module Generators () where

#if !MIN_VERSION_base(4, 8, 0)
import Data.Functor ((<$>))
import Control.Applicative (pure, (<*>))
#endif

import GHC.Generics (Generic)
import Generic.Random (genericArbitraryU, genericArbitraryRec, (%))
import Data.Bitraversable (bitraverse)
import Data.List.NonEmpty (NonEmpty(..))
import Data.Scientific (Scientific, scientific)
import Data.Text (Text, pack, cons)
import Test.QuickCheck (Arbitrary(..), shrinkList, Gen,
                        oneof, choose, suchThat, listOf, listOf1)

import Data.TPTP


-- * Helpers

instance Arbitrary s => Arbitrary (NonEmpty s) where
  arbitrary = genericArbitraryRec (1 % ())

deriving instance Generic (Name s)
instance (Named s, Enum s, Bounded s, Arbitrary s) => Arbitrary (Name s) where
  arbitrary = genericArbitraryU

shrinkMaybe :: (a -> [a]) -> Maybe a -> [Maybe a]
shrinkMaybe s = \case
  Nothing -> []
  Just a  -> Nothing : fmap Just (s a)

lowerAlpha, upperAlpha, printable, numeric, alphaNumeric :: Gen Char
lowerAlpha   = choose ('a', 'z')
upperAlpha   = choose ('A', 'Z')
numeric      = choose ('0', '9')
printable    = choose (' ', '~')
alphaNumeric = oneof [pure '_', lowerAlpha, upperAlpha, numeric]

lowerWord, upperWord, listOfPrintable, listOfPrintable1 :: Gen Text
lowerWord = cons <$> lowerAlpha <*> (pack <$> listOf alphaNumeric)
upperWord = cons <$> upperAlpha <*> (pack <$> listOf alphaNumeric)
listOfPrintable  = pack <$> listOf  printable
listOfPrintable1 = pack <$> listOf1 printable


-- * Names

instance Arbitrary Atom where
  arbitrary = Atom <$> oneof [lowerWord, listOfPrintable1]

instance Arbitrary Var where
  arbitrary = Var <$> upperWord

instance Arbitrary DistinctObject where
  arbitrary = DistinctObject <$> listOfPrintable

deriving instance Generic (Reserved s)
instance (Arbitrary s, Named s, Enum s, Bounded s) => Arbitrary (Reserved s) where
  arbitrary = oneof [
      Standard <$> arbitrary,
      extended <$> lowerWord
    ]

deriving instance Generic Function
instance Arbitrary Function where
  arbitrary = genericArbitraryU

deriving instance Generic Predicate
instance Arbitrary Predicate where
  arbitrary = genericArbitraryU


-- * Sorts and types

deriving instance Generic Sort
instance Arbitrary Sort where
  arbitrary = genericArbitraryU

deriving instance Generic TFF1Sort
instance Arbitrary TFF1Sort where
  arbitrary = genericArbitraryRec (1 % 1 % ())
  shrink = \case
    SortVariable{} -> []
    TFF1Sort  f ss -> ss ++ (TFF1Sort f <$> shrinkList shrink ss)

deriving instance Generic Type
instance Arbitrary Type where
  arbitrary = genericArbitraryU
  shrink = \case
    Type        as r -> Type     <$>               shrinkList shrink as <*> shrink r
    TFF1Type vs as r -> TFF1Type <$> shrink vs <*> shrinkList shrink as <*> shrink r


-- * First-order logic

instance Arbitrary Scientific where
  arbitrary = scientific <$> arbitrary <*> arbitrary

instance Arbitrary Number where
  arbitrary = oneof [
      IntegerConstant  <$> arbitrary,
      RationalConstant <$> arbitrary <*> arbitrary `suchThat` (> 0),
      RealConstant     <$> arbitrary
    ]

deriving instance Generic Term
instance Arbitrary Term where
  arbitrary = genericArbitraryRec (2 % 3 % 1 % 1 % ())
  shrink = \case
    Function f ts -> ts ++ (Function f <$> shrinkList shrink ts)
    _ -> []

deriving instance Generic Literal
instance Arbitrary Literal where
  arbitrary = genericArbitraryU
  shrink = \case
    Predicate p ts -> Predicate p <$> shrinkList shrink ts
    Equality a s b -> Equality <$> shrink a <*> pure s <*> shrink b

deriving instance Generic Sign
instance Arbitrary Sign where
  arbitrary = genericArbitraryU

deriving instance Generic Clause
instance Arbitrary Clause where
  arbitrary = genericArbitraryU
  shrink (Clause ls) = Clause <$> shrink ls

deriving instance Generic Quantifier
instance Arbitrary Quantifier where
  arbitrary = genericArbitraryU

deriving instance Generic Connective
instance Arbitrary Connective where
  arbitrary = genericArbitraryU

deriving instance Generic Unsorted
instance Arbitrary Unsorted where
  arbitrary = genericArbitraryU

deriving instance Generic (Sorted s)
instance Arbitrary s => Arbitrary (Sorted s) where
  arbitrary = genericArbitraryU
  shrink (Sorted s) = Sorted <$> shrinkMaybe shrink s

deriving instance Generic QuantifiedSort
instance Arbitrary QuantifiedSort where
  arbitrary = genericArbitraryU
  shrink _ = []

deriving instance Generic (FirstOrder s)
instance Arbitrary s => Arbitrary (FirstOrder s) where
  arbitrary = genericArbitraryRec (3 % 2 % 2 % 1 % ())
  shrink = \case
    Atomic          l -> Atomic <$> shrink l
    Negated         f -> f : (Negated <$> shrink f)
    Quantified q vs f -> f : (Quantified q vs <$> shrink f)
    Connected   f c g -> f : g : (Connected <$> shrink f <*> pure c <*> shrink g)

-- * Quantified modal logic

deriving instance Generic Modality
instance Arbitrary Modality where
  arbitrary = genericArbitraryU

deriving instance Generic (QuantifiedModal)
instance Arbitrary (QuantifiedModal) where
  arbitrary = genericArbitraryRec (3 % 2 % 2 % 1 % 1 % ())
  shrink = \case
    MAtomic          l -> MAtomic <$> shrink l
    MNegated         f -> f : (MNegated <$> shrink f)
    MConnected   f c g -> f : g : (MConnected <$> shrink f <*> pure c <*> shrink g)
    MQuantified q vs f -> f : (MQuantified q vs <$> shrink f)
    Modaled        m f -> f : (Modaled m <$> shrink f)

-- * Units

deriving instance Generic Formula
instance Arbitrary Formula where
  arbitrary = genericArbitraryU
  shrink = \case
    CNF  c -> CNF  <$> shrink c
    FOF  f -> FOF  <$> shrink f
    TFF0 f -> TFF0 <$> shrink f
    TFF1 f -> TFF1 <$> shrink f
    QMF  f -> QMF  <$> shrink f

deriving instance Generic Role
instance Arbitrary Role where
  arbitrary = genericArbitraryU

deriving instance Generic Declaration
instance Arbitrary Declaration where
  arbitrary = oneof [
      Sort    <$> arbitrary <*> choose (0, 3),
      Typing  <$> arbitrary <*> arbitrary,
      Formula <$> arbitrary <*> arbitrary
    ]
  shrink = \case
    Sort    a n -> Sort    a <$> shrink n
    Typing  n t -> Typing  n <$> shrink t
    Formula r f -> Formula r <$> shrink f

deriving instance Generic Unit
instance Arbitrary Unit where
  arbitrary = genericArbitraryRec (1 % 10 % ())
  shrink = \case
    Include f ns -> Include f <$> shrink ns
    Unit   n d a -> Unit    n <$> shrink d <*> shrinkAnnotation a
      where
        shrinkAnnotation = shrinkMaybe $ bitraverse shrink (shrinkMaybe shrink)

deriving instance Generic TPTP
instance Arbitrary TPTP where
  arbitrary = genericArbitraryU
  shrink (TPTP us) = TPTP <$> shrinkList shrink us

deriving instance Generic TSTP
instance Arbitrary TSTP where
  arbitrary = genericArbitraryU
  shrink (TSTP szs us) = TSTP <$> shrink szs <*> shrinkList shrink us


-- * Annotations

deriving instance Generic Intro
instance Arbitrary Intro where
  arbitrary = genericArbitraryU

deriving instance Generic SZS
instance Arbitrary SZS where
  arbitrary = genericArbitraryU

deriving instance Generic Success
instance Arbitrary Success where
  arbitrary = genericArbitraryU

deriving instance Generic NoSuccess
instance Arbitrary NoSuccess where
  arbitrary = genericArbitraryU

deriving instance Generic Dataform
instance Arbitrary Dataform where
  arbitrary = genericArbitraryU

deriving instance Generic Info
instance Arbitrary Info where
  arbitrary = genericArbitraryRec (1 % 1 % 1 % 1 % 1 % 1 % 1 % 1 % 1 % 1 % 1 % ())
  shrink = \case
    Description{}    -> []
    Iquote{}         -> []
    Status{}         -> []
    Refutation{}     -> []
    InfoNumber{}     -> []
    Assumptions   un -> Assumptions   <$> shrink un
    NewSymbols  n ss -> NewSymbols  n <$> shrink ss
    Expression     e -> Expression    <$> shrink e
    Bind         v e -> Bind        v <$> shrink e
    Application f as -> Application f <$> shrinkList shrink as
    Infos         is -> Infos         <$> shrinkList shrink is

deriving instance Generic Source
instance Arbitrary Source where
  arbitrary = genericArbitraryRec (1 % 1 % 1 % 1 % 1 % 1 % 1 % ())
  shrink = \case
    UnknownSource    -> []
    UnitSource{}     -> []
    File{}           -> []
    Theory      n is -> Theory     n <$> shrinkMaybe shrink is
    Creator     n is -> Creator    n <$> shrinkMaybe shrink is
    Introduced  i is -> Introduced i <$> shrinkMaybe shrink is
    Inference n i ps -> Inference  n <$> shrink i <*> ps'
      where ps' = concatMap (shrinkList shrink) (shrink ps)

deriving instance Generic Parent
instance Arbitrary Parent where
  arbitrary = genericArbitraryRec (1 % ())
  shrink (Parent s i) = Parent <$> shrink s <*> shrinkList shrink i

deriving instance Generic Expression
instance Arbitrary Expression where
  arbitrary = genericArbitraryRec (2 % 1 % ())
  shrink = \case
    Logical f -> Logical <$> shrink f
    Term    t -> Term    <$> shrink t
