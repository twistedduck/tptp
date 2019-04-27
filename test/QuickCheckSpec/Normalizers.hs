{-# LANGUAGE LambdaCase #-}

-- |
-- Module       : Normalizers
-- Description  : Normalization of the Data.TPTP datatypes.
-- Copyright    : (c) Evgenii Kotelnikov, 2019
-- License      : GPL-3
-- Maintainer   : evgeny.kotelnikov@gmail.com
-- Stability    : experimental
--
-- Provides functions that make applications of associative logical connectives
-- left-associative. These functions are needed for testing in the 'Main' module
--

module Normalizers (
  reassociate,
  normalizeType,
  normalizeUnit,
  normalizeDerivation,
  normalizeSource,
  normalizeParent,
  normalizeGeneralData,
  normalizeGeneralTerm,
  normalizeInfo
) where

import Data.TPTP
import Data.TPTP.Internal


-- * First-order logic

-- | 'reassociate' makes applications of associative connectives
-- left associative
reassociate :: FirstOrder s -> FirstOrder s
reassociate = \case
  Atomic l -> Atomic l
  Negated f -> Negated (reassociate f)
  Quantified q vs f -> Quantified q vs (reassociate f)
  Connected f c (Connected g c' h) | c == c' && isAssociative c ->
    reassociate (Connected (Connected f c g) c h)
  Connected f c g -> Connected (reassociate f) c (reassociate g)


-- * Units

normalizeFormula :: Formula -> Formula
normalizeFormula = \case
  CNF   c -> CNF c
  FOF  uf -> FOF (reassociate uf)
  TFF0 sf -> TFF0 (reassociate sf)
  TFF1 sf -> case monomorphizeFirstOrder sf of
    Nothing  -> TFF1 (reassociate sf)
    Just sf' -> TFF0 (reassociate sf')

normalizeType :: Type -> Type
normalizeType = \case
  TFF1Type vs ss s -> tff1Type vs ss s
  t -> t

normalizeDeclaration :: Declaration -> Declaration
normalizeDeclaration = \case
  Formula r f -> Formula r (normalizeFormula f)
  Typing  a t -> Typing  a (normalizeType t)
  d -> d

normalizeUnit :: Unit -> Unit
normalizeUnit = \case
  Include f ns -> Include f ns
  Unit n d a -> Unit n (normalizeDeclaration d) (normalizeAnn a)
    where
      normalizeAnn = fmap $ \(s, i) -> (normalizeSource s, fmap normalizeInfo i)

normalizeDerivation :: Derivation -> Derivation
normalizeDerivation (Derivation us) = Derivation (fmap normalizeUnit us)


-- * Annotations

normalizeSource :: Source -> Source
normalizeSource = \case
  Theory f i -> Theory f (fmap normalizeInfo i)
  Creator f i -> Creator f (fmap normalizeInfo i)
  Introduced i inf -> Introduced i (fmap normalizeInfo inf)
  Inference f i ps -> Inference f (normalizeInfo i) (fmap normalizeParent ps)
  s -> s

normalizeParent :: Parent -> Parent
normalizeParent (Parent s gts) =
  Parent (normalizeSource s) (fmap normalizeGeneralTerm gts)

normalizeExpression :: Expression -> Expression
normalizeExpression = \case
  Logical f -> Logical (normalizeFormula f)
  Term    t -> Term t

normalizeGeneralData :: GeneralData -> GeneralData
normalizeGeneralData = \case
  GeneralFunction f gts -> GeneralFunction f (fmap normalizeGeneralTerm gts)
  GeneralExpression e -> GeneralExpression (normalizeExpression e)
  GeneralBind v e -> GeneralBind v (normalizeExpression e)
  gd -> gd

normalizeGeneralTerm :: GeneralTerm -> GeneralTerm
normalizeGeneralTerm = \case
  GeneralData gd gt -> GeneralData (normalizeGeneralData gd)
                                   (fmap normalizeGeneralTerm gt)
  GeneralList gts -> GeneralList (fmap normalizeGeneralTerm gts)

normalizeInfo :: Info -> Info
normalizeInfo (Info gts) = Info (fmap normalizeGeneralTerm gts)
