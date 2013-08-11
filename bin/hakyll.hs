--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

import           Data.Monoid (mappend)
import           Control.Applicative
import           Text.Pandoc.Options
import           System.FilePath
import           Hakyll

--------------------------------------------------------------------------------

main :: IO ()
main = hakyllWith config $ do
    match "static/**" $ do
        route   setRoot
        compile copyFileCompiler

    -- Tell hakyll to watch the less files
    match "assets/less/**.less" $ do
        compile getResourceBody

    -- Compile the main less file
    -- We tell hakyll it depends on all the less files,
    -- so it will recompile it when needed
    d <- makePatternDependency "assets/less/**.less"
    rulesExtraDependencies [d] $ create ["css/main.css"] $ do
        route idRoute
        compile $ loadBody "assets/less/main.less"
            >>= makeItem
            >>= withItemBody 
                (unixFilter "lessc" ["-","--include-path=assets/less","--yui-compress","-O2"])

    match "**.coffee" $ do
        route $ setRoot `composeRoutes` setExtension "js"
        compile $ getResourceString
            >>= withItemBody
                (unixFilter "coffee" ["--stdio", "--compile"])

    match "assets/js/**.js" $ do
        route $ setRoot `composeRoutes` setExtension "js"
        compile $ copyFileCompiler

    match ("pages/**") $ do
        route   $ setRoot `composeRoutes` setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" baseCtx
            >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

--------------------------------------------------------------------------------

pandocWriterOptions :: WriterOptions
pandocWriterOptions = defaultHakyllWriterOptions { writerHTMLMathMethod = MathJax "" }

stripIndexLink :: (Item a -> Compiler String)
stripIndexLink = (fmap (maybe empty (dropFileName . toUrl)) . getRoute . itemIdentifier)

baseCtx :: Context String
baseCtx =
    field "url" stripIndexLink `mappend`
    defaultContext

setRoot :: Routes
setRoot = customRoute stripTopDir

stripTopDir :: Identifier -> FilePath
stripTopDir = joinPath . tail . splitPath . toFilePath

cleanURL :: Routes
cleanURL = customRoute fileToDirectory

fileToDirectory :: Identifier -> FilePath
fileToDirectory = (flip combine) "index.html" . dropExtension . toFilePath

config :: Configuration
config = defaultConfiguration {
        deployCommand = "rsync -av _site/ hamr@aum.dartmouth.edu:web/"
    }
