-- | Página inicial.
module Handler.Home where

import Yesod

import Foundation

getHomeR :: Handler Html
getHomeR = defaultLayout $ do
    setTitle "Biblioteca"
    [whamlet|<h1>Biblioteca|]
