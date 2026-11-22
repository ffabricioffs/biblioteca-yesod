-- | CRUD de Categorias.
module Handler.Categoria where

import Yesod

import Foundation
import Handler.Comum
import Models

-- | Formulário. Recebe a categoria atual (Just) ao editar ou Nothing ao criar.
categoriaForm :: Maybe Categoria -> Form Categoria
categoriaForm atual = renderDivs $ Categoria
    <$> areq textField "Nome"      (categoriaNome <$> atual)
    <*> aopt textField "Descrição" (categoriaDescricao <$> atual)

-- READ: lista todas as categorias em ordem alfabética.
getCategoriasR :: Handler Html
getCategoriasR = do
    categorias <- runDB $ selectList [] [Asc CategoriaNome]
    defaultLayout $ do
        setTitle "Categorias"
        $(whamletFile "templates/categorias/lista.hamlet")

-- CREATE (GET mostra o formulário vazio).
getCategoriaNovaR :: Handler Html
getCategoriaNovaR = do
    (widget, enctype) <- generateFormPost (categoriaForm Nothing)
    paginaFormulario "Nova categoria" CategoriaNovaR CategoriasR widget enctype

-- CREATE (POST recebe os dados e grava).
postCategoriaNovaR :: Handler Html
postCategoriaNovaR = do
    ((resultado, widget), enctype) <- runFormPost (categoriaForm Nothing)
    case resultado of
        FormSuccess categoria -> do
            -- insertUnique devolve Nothing se violar UniqueCategoriaNome
            inserido <- runDB $ insertUnique categoria
            case inserido of
                Just _ -> do
                    msgSucesso "Categoria cadastrada."
                    redirect CategoriasR
                Nothing -> do
                    msgErro "Já existe uma categoria com esse nome."
                    paginaFormulario "Nova categoria" CategoriaNovaR CategoriasR widget enctype
        _ -> paginaFormulario "Nova categoria" CategoriaNovaR CategoriasR widget enctype

-- UPDATE (GET mostra o formulário preenchido).
getCategoriaEditarR :: CategoriaId -> Handler Html
getCategoriaEditarR cid = do
    categoria <- runDB $ get404 cid
    (widget, enctype) <- generateFormPost (categoriaForm (Just categoria))
    paginaFormulario "Editar categoria" (CategoriaEditarR cid) CategoriasR widget enctype

-- UPDATE (POST grava as alterações).
postCategoriaEditarR :: CategoriaId -> Handler Html
postCategoriaEditarR cid = do
    categoria <- runDB $ get404 cid
    ((resultado, widget), enctype) <- runFormPost (categoriaForm (Just categoria))
    case resultado of
        FormSuccess nova -> do
            -- Procura OUTRA categoria com o mesmo nome antes de gravar.
            existente <- runDB $ getBy (UniqueCategoriaNome (categoriaNome nova))
            case existente of
                Just (Entity outroId _) | outroId /= cid -> do
                    msgErro "Já existe uma categoria com esse nome."
                    paginaFormulario "Editar categoria" (CategoriaEditarR cid) CategoriasR widget enctype
                _ -> do
                    runDB $ replace cid nova
                    msgSucesso "Categoria atualizada."
                    redirect CategoriasR
        _ -> paginaFormulario "Editar categoria" (CategoriaEditarR cid) CategoriasR widget enctype

-- DELETE: só exclui se nenhum livro usar a categoria (integridade da FK).
postCategoriaExcluirR :: CategoriaId -> Handler Html
postCategoriaExcluirR cid = do
    _ <- runDB $ get404 cid
    qtdLivros <- runDB $ count [LivroCategoriaId ==. cid]
    if qtdLivros > 0
        then msgErro "Não é possível excluir: existem livros nesta categoria."
        else do
            runDB $ delete cid
            msgSucesso "Categoria excluída."
    redirect CategoriasR
