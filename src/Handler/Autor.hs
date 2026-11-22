-- | CRUD de Autores.
module Handler.Autor where

import Yesod

import Foundation
import Handler.Comum
import Models

autorForm :: Maybe Autor -> Form Autor
autorForm atual = renderDivs $ Autor
    <$> areq textField "Nome"          (autorNome <$> atual)
    <*> aopt textField "Nacionalidade" (autorNacionalidade <$> atual)

getAutoresR :: Handler Html
getAutoresR = do
    autores <- runDB $ selectList [] [Asc AutorNome]
    defaultLayout $ do
        setTitle "Autores"
        $(whamletFile "templates/autores/lista.hamlet")

getAutorNovoR :: Handler Html
getAutorNovoR = do
    (widget, enctype) <- generateFormPost (autorForm Nothing)
    paginaFormulario "Novo autor" AutorNovoR AutoresR widget enctype

postAutorNovoR :: Handler Html
postAutorNovoR = do
    ((resultado, widget), enctype) <- runFormPost (autorForm Nothing)
    case resultado of
        FormSuccess autor -> do
            _ <- runDB $ insert autor
            msgSucesso "Autor cadastrado."
            redirect AutoresR
        _ -> paginaFormulario "Novo autor" AutorNovoR AutoresR widget enctype

getAutorEditarR :: AutorId -> Handler Html
getAutorEditarR aid = do
    autor <- runDB $ get404 aid
    (widget, enctype) <- generateFormPost (autorForm (Just autor))
    paginaFormulario "Editar autor" (AutorEditarR aid) AutoresR widget enctype

postAutorEditarR :: AutorId -> Handler Html
postAutorEditarR aid = do
    autor <- runDB $ get404 aid
    ((resultado, widget), enctype) <- runFormPost (autorForm (Just autor))
    case resultado of
        FormSuccess novo -> do
            runDB $ replace aid novo
            msgSucesso "Autor atualizado."
            redirect AutoresR
        _ -> paginaFormulario "Editar autor" (AutorEditarR aid) AutoresR widget enctype

-- Não exclui autor ligado a algum livro (tabela livro_autor).
postAutorExcluirR :: AutorId -> Handler Html
postAutorExcluirR aid = do
    _ <- runDB $ get404 aid
    qtdLivros <- runDB $ count [LivroAutorAutorId ==. aid]
    if qtdLivros > 0
        then msgErro "Não é possível excluir: o autor está vinculado a livros."
        else do
            runDB $ delete aid
            msgSucesso "Autor excluído."
    redirect AutoresR
