-- | Página inicial: a estante com os livros do acervo, os números da
-- circulação e a lista de devoluções atrasadas.
module Handler.Home where

import Control.Monad (forM)
import Yesod

import Foundation
import Handler.Comum
import Models

getHomeR :: Handler Html
getHomeR = do
    dia <- hoje
    (qtdLivros, qtdLeitores, qtdAtivos, livros, atrasadosE) <- runDB $ do
        l  <- count ([] :: [Filter Livro])
        le <- count ([] :: [Filter Leitor])
        a  <- count [EmprestimoDataDevolucao ==. Nothing]
        -- até 40 livros na estante, em ordem alfabética
        ls <- selectList [] [Asc LivroTitulo, LimitTo 40]
        -- empréstimos em aberto com a data prevista já vencida
        at <- selectList [EmprestimoDataDevolucao ==. Nothing, EmprestimoDataPrevista <. dia]
                         [Asc EmprestimoDataPrevista]
        pure (l, le, a, ls, at)
    atrasados <- forM atrasadosE $ \(Entity eid e) -> do
        livro  <- runDB $ getJust (emprestimoLivroId e)
        leitor <- runDB $ getJust (emprestimoLeitorId e)
        pure (eid, e, livro, leitor)
    let qtdAtrasados = length atrasados
        temAtrasos   = qtdAtrasados > 0
    defaultLayout $ do
        setTitle "Início"
        $(whamletFile "templates/home.hamlet")
