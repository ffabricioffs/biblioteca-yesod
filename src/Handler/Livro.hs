-- | CRUD de Livros, incluindo o relacionamento N:N com Autores
-- (tabela livro_autor) e o cálculo de exemplares disponíveis.
module Handler.Livro where

import Control.Monad (forM, forM_)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Yesod

import Foundation
import Handler.Comum
import Models

-- | O formulário devolve o livro E a lista de autores marcados.
livroForm :: Maybe (Livro, [AutorId]) -> Form (Livro, [AutorId])
livroForm atual = renderDivs $ (,)
    <$> (Livro
        <$> areq textField "Título" (livroTitulo . fst <$> atual)
        <*> aopt textField "ISBN" (livroIsbn . fst <$> atual)
        <*> aopt anoField "Ano de publicação" (livroAnoPublicacao . fst <$> atual)
        <*> areq quantidadeField "Quantidade de exemplares" (livroQuantidade . fst <$> atual)
        <*> areq (selectField editoras) "Editora" (livroEditoraId . fst <$> atual)
        <*> areq (selectField categorias) "Categoria" (livroCategoriaId . fst <$> atual))
    <*> areq (checkboxesField autores) "Autores" (snd <$> atual)
  where
    -- Opções dos campos de seleção vindas do banco.
    editoras   = optionsPersistKey [] [Asc EditoraNome] editoraNome
    categorias = optionsPersistKey [] [Asc CategoriaNome] categoriaNome
    autores    = optionsPersistKey [] [Asc AutorNome] autorNome
    -- Validações.
    anoField = checkBool (\a -> a >= 1450 && a <= 2100)
                         ("Ano inválido." :: Text) intField
    quantidadeField = checkBool (>= 0)
                         ("A quantidade não pode ser negativa." :: Text) intField

-- | Quantos exemplares do livro estão emprestados agora
-- (empréstimos sem data de devolução).
emprestimosAtivos :: LivroId -> Handler Int
emprestimosAtivos lid =
    runDB $ count [EmprestimoLivroId ==. lid, EmprestimoDataDevolucao ==. Nothing]

-- READ: lista com busca opcional por título (?busca=...).
getLivrosR :: Handler Html
getLivrosR = do
    busca <- fromMaybe "" <$> lookupGetParam "busca"
    livros <- runDB $ selectList [] [Asc LivroTitulo]
    let filtrados = filter (combina busca . livroTitulo . entityVal) livros
    -- Para cada livro buscamos a editora, a categoria e a disponibilidade.
    itens <- forM filtrados $ \(Entity lid livro) -> do
        editora   <- runDB $ getJust (livroEditoraId livro)
        categoria <- runDB $ getJust (livroCategoriaId livro)
        ativos    <- emprestimosAtivos lid
        pure (lid, livro, editora, categoria, livroQuantidade livro - ativos)
    defaultLayout $ do
        setTitle "Livros"
        $(whamletFile "templates/livros/lista.hamlet")
  where
    combina termo titulo = T.toLower (T.strip termo) `T.isInfixOf` T.toLower titulo

-- READ (detalhe): autores do livro e histórico de empréstimos.
getLivroR :: LivroId -> Handler Html
getLivroR lid = do
    dia <- hoje
    livro     <- runDB $ get404 lid
    editora   <- runDB $ getJust (livroEditoraId livro)
    categoria <- runDB $ getJust (livroCategoriaId livro)
    vinculos  <- runDB $ selectList [LivroAutorLivroId ==. lid] []
    autores   <- runDB $ forM vinculos $ getJust . livroAutorAutorId . entityVal
    emprestimos <- runDB $ selectList [EmprestimoLivroId ==. lid] [Desc EmprestimoDataEmprestimo]
    historico <- forM emprestimos $ \(Entity _ e) -> do
        leitor <- runDB $ getJust (emprestimoLeitorId e)
        pure (e, leitor)
    ativos <- emprestimosAtivos lid
    let disponiveis = livroQuantidade livro - ativos
    defaultLayout $ do
        setTitle (toHtml (livroTitulo livro))
        $(whamletFile "templates/livros/detalhes.hamlet")

getLivroNovoR :: Handler Html
getLivroNovoR = do
    (widget, enctype) <- generateFormPost (livroForm Nothing)
    paginaFormulario "Novo livro" LivroNovoR LivrosR widget enctype

-- CREATE: insere o livro e depois uma linha em livro_autor para cada
-- autor marcado. Tudo dentro do mesmo runDB = mesma transação.
postLivroNovoR :: Handler Html
postLivroNovoR = do
    ((resultado, widget), enctype) <- runFormPost (livroForm Nothing)
    case resultado of
        FormSuccess (livro, autorIds) -> do
            lid <- runDB $ do
                novoId <- insert livro
                forM_ autorIds $ \aid -> insert_ (LivroAutor novoId aid)
                pure novoId
            msgSucesso "Livro cadastrado."
            redirect (LivroR lid)
        _ -> paginaFormulario "Novo livro" LivroNovoR LivrosR widget enctype

getLivroEditarR :: LivroId -> Handler Html
getLivroEditarR lid = do
    livro    <- runDB $ get404 lid
    autorIds <- autoresDoLivro lid
    (widget, enctype) <- generateFormPost (livroForm (Just (livro, autorIds)))
    paginaFormulario "Editar livro" (LivroEditarR lid) (LivroR lid) widget enctype

-- UPDATE: substitui o livro e recria os vínculos com autores.
postLivroEditarR :: LivroId -> Handler Html
postLivroEditarR lid = do
    livro    <- runDB $ get404 lid
    autorIds <- autoresDoLivro lid
    ((resultado, widget), enctype) <- runFormPost (livroForm (Just (livro, autorIds)))
    case resultado of
        FormSuccess (novo, novosAutores) -> do
            ativos <- emprestimosAtivos lid
            if livroQuantidade novo < ativos
                then do
                    msgErro "A quantidade não pode ser menor que o número de exemplares emprestados."
                    paginaFormulario "Editar livro" (LivroEditarR lid) (LivroR lid) widget enctype
                else do
                    runDB $ do
                        replace lid novo
                        deleteWhere [LivroAutorLivroId ==. lid]
                        forM_ novosAutores $ \aid -> insert_ (LivroAutor lid aid)
                    msgSucesso "Livro atualizado."
                    redirect (LivroR lid)
        _ -> paginaFormulario "Editar livro" (LivroEditarR lid) (LivroR lid) widget enctype

-- DELETE: bloqueia se houver empréstimos; senão apaga vínculos e o livro.
postLivroExcluirR :: LivroId -> Handler Html
postLivroExcluirR lid = do
    _ <- runDB $ get404 lid
    qtdEmprestimos <- runDB $ count [EmprestimoLivroId ==. lid]
    if qtdEmprestimos > 0
        then do
            msgErro "Não é possível excluir: o livro possui empréstimos registrados."
            redirect (LivroR lid)
        else do
            runDB $ do
                deleteWhere [LivroAutorLivroId ==. lid]
                delete lid
            msgSucesso "Livro excluído."
            redirect LivrosR

-- | Ids dos autores vinculados a um livro.
autoresDoLivro :: LivroId -> Handler [AutorId]
autoresDoLivro lid = do
    vinculos <- runDB $ selectList [LivroAutorLivroId ==. lid] []
    pure (map (livroAutorAutorId . entityVal) vinculos)
