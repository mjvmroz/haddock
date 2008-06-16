--
-- Haddock - A Haskell Documentation Tool
--
-- (c) Simon Marlow 2003
--
-- This file, (c) Neil Mitchell 2006-2008
-- Write out Hoogle compatible documentation
-- http://www.haskell.org/hoogle/

module Haddock.Backends.Hoogle ( 
    ppHoogle
  ) where


import Haddock.Types
import Haddock.GHC
import GHC hiding ((<.>))
import SrcLoc
import Outputable

import Control.Monad
import Data.Char
import Data.List
import Data.Maybe
import System.FilePath


prefix = ["-- Hoogle documentation, generated by Haddock"
         ,"-- See Hoogle, http://www.haskell.org/hoogle/"
         ,""]


ppHoogle :: String -> String -> [Interface] -> FilePath -> IO ()
ppHoogle package version ifaces odir = do
    let filename = package <.> "txt"
        contents = prefix ++
                   ["@package " ++ package] ++
                   ["@version " ++ version | version /= ""] ++
                   concat [ppModule i | i <- ifaces, OptHide `notElem` ifaceOptions i]
    writeFile (odir </> filename) (unlines contents)


ppModule :: Interface -> [String]
ppModule iface = "" : doc (ifaceDoc iface) ++
                 ["module " ++ moduleString (ifaceMod iface)] ++
                 concatMap ppExport (ifaceExportItems iface) ++
                 concatMap ppInstance (ifaceInstances iface)


---------------------------------------------------------------------
-- Utility functions

indent = (++) "    "
unL (L _ x) = x


dropComment (' ':'-':'-':' ':_) = []
dropComment (x:xs) = x : dropComment xs
dropComment [] = []


out :: Outputable a => a -> String
out = f . unwords . map (dropWhile isSpace) . lines . showSDocUnqual . ppr
    where
        f xs | " <document comment>" `isPrefixOf` xs = f $ drop 19 xs
        f (x:xs) = x : f xs
        f [] = []


typeSig :: String -> [String] -> String
typeSig name flds = name ++ " :: " ++ concat (intersperse " -> " flds)


---------------------------------------------------------------------
-- How to print each export

ppExport :: ExportItem Name -> [String]
ppExport (ExportDecl name decl dc _) = doc dc ++ f (unL decl)
    where
        f (TyClD d@TyData{}) = ppData d
        f (TyClD d@ClassDecl{}) = ppClass d
        f decl = [out decl]
ppExport _ = []


-- note: does not yet output documentation for class methods
ppClass :: TyClDecl Name -> [String]
ppClass x = out x{tcdSigs=[]} :
            map (indent . out) (tcdSigs x)


ppInstance :: Instance -> [String]
ppInstance x = [dropComment $ out x]


ppData :: TyClDecl Name -> [String]
ppData x = showData x{tcdCons=[],tcdDerivs=Nothing} :
           concatMap (ppCtor x . unL) (tcdCons x)
    where
        -- GHC gives out "data Bar =", we want to delete the equals
        showData = reverse . dropWhile (`elem` " =") . reverse . out


ppCtor :: TyClDecl Name -> ConDecl Name -> [String]
ppCtor dat con = ldoc (con_doc con) ++ f (con_details con)
    where
        f (PrefixCon args) = [typeSig name $ map out args ++ [resType]]
        f (InfixCon a1 a2) = f $ PrefixCon [a1,a2]
        f (RecCon recs) = f (PrefixCon $ map cd_fld_type recs) ++ concat
                          [ldoc (cd_fld_doc r) ++
                           [out (unL $ cd_fld_name r) `typeSig` [resType, out $ cd_fld_type r]]
                          | r <- recs]

        name = out $ unL $ con_name con

        resType = case con_res con of
            ResTyH98 -> unwords $ out (tcdLName dat) : map out (tcdTyVars dat)
            ResTyGADT x -> out $ unL x


---------------------------------------------------------------------
-- How to show documentation

ldoc :: Maybe (LHsDoc Name) -> [String]
ldoc = doc . liftM unL

doc :: Maybe (HsDoc Name) -> [String]
doc Nothing = []
doc (Just d) = [] -- can add here, if wanted
