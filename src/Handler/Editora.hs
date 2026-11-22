-- | CRUD de Editoras (mesma estrutura do CRUD de Categorias).
module Handler.Editora where

import Yesod

import Foundation
import Handler.Comum
import Models

editoraForm :: Maybe Editora -> Form Editora
editoraForm atual = renderDivs $ Editora
    <$> areq textField "Nome"   (editoraNome <$> atual)
    <*> aopt textField "Cidade" (editoraCidade <$> atual)

getEditorasR :: Handler Html
getEditorasR = do
    editoras <- runDB $ selectList [] [Asc EditoraNome]
    defaultLayout $ do
        setTitle "Editoras"
        $(whamletFile "templates/editoras/lista.hamlet")

getEditoraNovaR :: Handler Html
getEditoraNovaR = do
    (widget, enctype) <- generateFormPost (editoraForm Nothing)
    paginaFormulario "Nova editora" EditoraNovaR EditorasR widget enctype

postEditoraNovaR :: Handler Html
postEditoraNovaR = do
    ((resultado, widget), enctype) <- runFormPost (editoraForm Nothing)
    case resultado of
        FormSuccess editora -> do
            inserido <- runDB $ insertUnique editora
            case inserido of
                Just _ -> do
                    msgSucesso "Editora cadastrada."
                    redirect EditorasR
                Nothing -> do
                    msgErro "Já existe uma editora com esse nome."
                    paginaFormulario "Nova editora" EditoraNovaR EditorasR widget enctype
        _ -> paginaFormulario "Nova editora" EditoraNovaR EditorasR widget enctype

getEditoraEditarR :: EditoraId -> Handler Html
getEditoraEditarR eid = do
    editora <- runDB $ get404 eid
    (widget, enctype) <- generateFormPost (editoraForm (Just editora))
    paginaFormulario "Editar editora" (EditoraEditarR eid) EditorasR widget enctype

postEditoraEditarR :: EditoraId -> Handler Html
postEditoraEditarR eid = do
    editora <- runDB $ get404 eid
    ((resultado, widget), enctype) <- runFormPost (editoraForm (Just editora))
    case resultado of
        FormSuccess nova -> do
            existente <- runDB $ getBy (UniqueEditoraNome (editoraNome nova))
            case existente of
                Just (Entity outroId _) | outroId /= eid -> do
                    msgErro "Já existe uma editora com esse nome."
                    paginaFormulario "Editar editora" (EditoraEditarR eid) EditorasR widget enctype
                _ -> do
                    runDB $ replace eid nova
                    msgSucesso "Editora atualizada."
                    redirect EditorasR
        _ -> paginaFormulario "Editar editora" (EditoraEditarR eid) EditorasR widget enctype

postEditoraExcluirR :: EditoraId -> Handler Html
postEditoraExcluirR eid = do
    _ <- runDB $ get404 eid
    qtdLivros <- runDB $ count [LivroEditoraId ==. eid]
    if qtdLivros > 0
        then msgErro "Não é possível excluir: existem livros desta editora."
        else do
            runDB $ delete eid
            msgSucesso "Editora excluída."
    redirect EditorasR
