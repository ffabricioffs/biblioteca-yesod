-- | Página inicial com números gerais da biblioteca.
module Handler.Home where

import Yesod

import Foundation
import Handler.Comum
import Models

getHomeR :: Handler Html
getHomeR = do
    dia <- hoje
    (qtdLivros, qtdLeitores, qtdAtivos, qtdAtrasados) <- runDB $ do
        l  <- count ([] :: [Filter Livro])
        le <- count ([] :: [Filter Leitor])
        a  <- count [EmprestimoDataDevolucao ==. Nothing]
        at <- count [EmprestimoDataDevolucao ==. Nothing, EmprestimoDataPrevista <. dia]
        pure (l, le, a, at)
    defaultLayout $ do
        setTitle "Biblioteca"
        $(whamletFile "templates/home.hamlet")
