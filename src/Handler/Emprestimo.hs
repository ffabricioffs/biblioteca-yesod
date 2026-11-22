-- | CRUD de Empréstimos + devolução, com as regras de negócio:
--   * só empresta se houver exemplar disponível;
--   * a devolução prevista não pode ser antes da data do empréstimo.
module Handler.Emprestimo where

import Control.Monad (forM)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, addDays)
import Yesod

import Foundation
import Handler.Comum
import Models

-- | Formulário. Em um empréstimo novo, as datas já vêm sugeridas
-- (hoje e hoje + 14 dias). A data de devolução não é editada aqui:
-- ela é mantida como está (ou Nothing, se for novo).
emprestimoForm :: Day -> Maybe Emprestimo -> Form Emprestimo
emprestimoForm dia atual = renderDivs $ Emprestimo
    <$> areq (selectField livros)   "Livro"  (emprestimoLivroId <$> atual)
    <*> areq (selectField leitores) "Leitor" (emprestimoLeitorId <$> atual)
    <*> areq dayField "Data do empréstimo"
            (Just (maybe dia emprestimoDataEmprestimo atual))
    <*> areq dayField "Devolução prevista"
            (Just (maybe (addDays 14 dia) emprestimoDataPrevista atual))
    <*> pure (atual >>= emprestimoDataDevolucao)
  where
    livros   = optionsPersistKey [] [Asc LivroTitulo] livroTitulo
    leitores = optionsPersistKey [] [Asc LeitorNome] leitorNome

-- | Verifica as regras antes de gravar. 'ignorar' é o próprio
-- empréstimo quando estamos editando (para não contar ele mesmo).
validarEmprestimo :: Maybe EmprestimoId -> Emprestimo -> Handler (Maybe Text)
validarEmprestimo ignorar e
    | emprestimoDataPrevista e < emprestimoDataEmprestimo e =
        pure (Just "A devolução prevista não pode ser anterior à data do empréstimo.")
    | emprestimoDataDevolucao e /= Nothing = pure Nothing  -- já devolvido: não ocupa exemplar
    | otherwise = do
        livro <- runDB $ getJust (emprestimoLivroId e)
        let filtroIgnorar = maybe [] (\eid -> [EmprestimoId !=. eid]) ignorar
        ativos <- runDB $ count $
            [ EmprestimoLivroId ==. emprestimoLivroId e
            , EmprestimoDataDevolucao ==. Nothing ] ++ filtroIgnorar
        pure $ if ativos >= livroQuantidade livro
            then Just ("Não há exemplares disponíveis de \"" <> livroTitulo livro <> "\".")
            else Nothing

-- READ: lista com filtro opcional ?situacao=ativos | atrasados
getEmprestimosR :: Handler Html
getEmprestimosR = do
    dia <- hoje
    situacao <- lookupGetParam "situacao"
    let filtros = case situacao of
            Just "ativos"    -> [EmprestimoDataDevolucao ==. Nothing]
            Just "atrasados" -> [EmprestimoDataDevolucao ==. Nothing, EmprestimoDataPrevista <. dia]
            _                -> []
    emprestimos <- runDB $ selectList filtros [Desc EmprestimoDataEmprestimo]
    itens <- forM emprestimos $ \(Entity eid e) -> do
        livro  <- runDB $ getJust (emprestimoLivroId e)
        leitor <- runDB $ getJust (emprestimoLeitorId e)
        pure (eid, e, livro, leitor)
    defaultLayout $ do
        setTitle "Empréstimos"
        $(whamletFile "templates/emprestimos/lista.hamlet")

getEmprestimoNovoR :: Handler Html
getEmprestimoNovoR = do
    dia <- hoje
    (widget, enctype) <- generateFormPost (emprestimoForm dia Nothing)
    paginaFormulario "Novo empréstimo" EmprestimoNovoR EmprestimosR widget enctype

postEmprestimoNovoR :: Handler Html
postEmprestimoNovoR = do
    dia <- hoje
    ((resultado, widget), enctype) <- runFormPost (emprestimoForm dia Nothing)
    let voltarAoForm = paginaFormulario "Novo empréstimo" EmprestimoNovoR EmprestimosR widget enctype
    case resultado of
        FormSuccess emprestimo -> do
            problema <- validarEmprestimo Nothing emprestimo
            case problema of
                Just erro -> msgErro erro >> voltarAoForm
                Nothing -> do
                    _ <- runDB $ insert emprestimo
                    msgSucesso "Empréstimo registrado."
                    redirect EmprestimosR
        _ -> voltarAoForm

getEmprestimoEditarR :: EmprestimoId -> Handler Html
getEmprestimoEditarR eid = do
    dia <- hoje
    emprestimo <- runDB $ get404 eid
    (widget, enctype) <- generateFormPost (emprestimoForm dia (Just emprestimo))
    paginaFormulario "Editar empréstimo" (EmprestimoEditarR eid) EmprestimosR widget enctype

postEmprestimoEditarR :: EmprestimoId -> Handler Html
postEmprestimoEditarR eid = do
    dia <- hoje
    emprestimo <- runDB $ get404 eid
    ((resultado, widget), enctype) <- runFormPost (emprestimoForm dia (Just emprestimo))
    let voltarAoForm = paginaFormulario "Editar empréstimo" (EmprestimoEditarR eid) EmprestimosR widget enctype
    case resultado of
        FormSuccess novo -> do
            problema <- validarEmprestimo (Just eid) novo
            case problema of
                Just erro -> msgErro erro >> voltarAoForm
                Nothing -> do
                    runDB $ replace eid novo
                    msgSucesso "Empréstimo atualizado."
                    redirect EmprestimosR
        _ -> voltarAoForm

-- UPDATE parcial: registra a devolução com a data de hoje.
postEmprestimoDevolverR :: EmprestimoId -> Handler Html
postEmprestimoDevolverR eid = do
    emprestimo <- runDB $ get404 eid
    case emprestimoDataDevolucao emprestimo of
        Just _ -> msgErro "Este empréstimo já foi devolvido."
        Nothing -> do
            dia <- hoje
            runDB $ update eid [EmprestimoDataDevolucao =. Just dia]
            msgSucesso "Devolução registrada."
    redirect EmprestimosR

postEmprestimoExcluirR :: EmprestimoId -> Handler Html
postEmprestimoExcluirR eid = do
    _ <- runDB $ get404 eid
    runDB $ delete eid
    msgSucesso "Empréstimo excluído."
    redirect EmprestimosR

-- | Usado no template para marcar o filtro selecionado.
filtroAtivo :: Maybe Text -> Text -> Bool
filtroAtivo atual nome = maybe "todos" T.strip atual == nome
