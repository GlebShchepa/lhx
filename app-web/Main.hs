{-# LANGUAGE RecordWildCards #-}

module Main where

import Web.Scotty
import Data.Either (rights)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Text.Blaze.Html.Renderer.Text qualified as R
import Text.Blaze.Html5 (Html, (!))
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A
import Text.Blaze (toMarkup, toValue)

import Lhx qualified

data FormState = FormState
  { fsInput         :: Text
  , fsTemplate      :: Text
  , fsTemplateError :: Maybe Text
  , fsOutput        :: Text
  }

main :: IO ()
main = scotty 8000 do
  get "/" $ view FormState
    { fsInput = ""
    , fsTemplate = ""
    , fsTemplateError = Nothing
    , fsOutput = ""
    }
  post "/" do
    fsInput <- param "input"
    fsTemplate <- param "template"
    oldOutput <- param "output"
    let (fsOutput, fsTemplateError) =
          case Lhx.makeTemplate fsTemplate of
            Left es -> (oldOutput, Just . T.unlines $ map Lhx.getError es)
            Right t ->
              let ls = webLines fsInput
                  input = map (Lhx.makeInput (Lhx.Separator ",")) ls
                  out = T.unlines . rights $ map (Lhx.apply t) input
              in (out, Nothing)
    view FormState{..}

view :: FormState -> ActionM ()
view FormState{..} = page do
  H.form ! A.method "POST" $ do
    H.label do
      "Input:"
      H.textarea
        ! A.name "input"
        $ toMarkup fsInput
    let
      tplStyle :: Text
      tplStyle = case fsTemplateError of
        Just _ -> "border-color: red;"
        _      -> ""
    H.label do
      "Template:"
      H.input
        ! A.name "template"
        ! A.title (toValue $ fromMaybe "" fsTemplateError)
        ! A.style (toValue tplStyle)
        ! A.value (toValue fsTemplate)
    H.label do
      "Output:"
      H.textarea
        ! A.readonly (toValue True)
        ! A.name "output"
        $ toMarkup fsOutput
    H.button ! A.action "submit" $ "Submit"

page :: Html -> ActionM ()
page inner = html $ R.renderHtml do
  H.docTypeHtml do
    H.head do
      H.title "LHX"
      H.link
        ! A.rel "stylesheet"
        ! A.href "https://unpkg.com/mvp.css@1.11/mvp.css"
    H.body do
      inner

webLines :: Text -> [Text]
webLines = T.split (== '\n') . T.filter (/= '\r')
