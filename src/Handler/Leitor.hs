-- | CRUD de Leitores. Aqui está o CONSUMO DA API EXTERNA: o usuário
-- digita só o CEP e o número; logradouro, bairro, cidade e UF vêm do
-- ViaCEP e são gravados no banco.
module Handler.Leitor where

import Control.Monad (forM)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Yesod

import Api.ViaCep
import Foundation
import Handler.Comum
import Models

-- | O que o usuário preenche (o endereço completo NÃO está aqui).
data LeitorDados = LeitorDados
    { ldNome     :: Text
    , ldEmail    :: Text
    , ldTelefone :: Maybe Text
    , ldCep      :: Text
    , ldNumero   :: Text
    }

leitorForm :: Maybe Leitor -> Form LeitorDados
leitorForm atual = renderDivs $ LeitorDados
    <$> areq textField  "Nome"     (leitorNome <$> atual)
    <*> areq emailField "E-mail"   (leitorEmail <$> atual)
    <*> aopt textField  "Telefone" (leitorTelefone <$> atual)
    <*> areq cepField   cepSettings (leitorCep <$> atual)
    <*> areq textField  "Número"   (leitorNumero <$> atual)
  where
    cepField = checkBool ((/= Nothing) . normalizarCep)
                         ("CEP inválido: informe 8 dígitos." :: Text) textField
    cepSettings = FieldSettings
        { fsLabel = "CEP (o endereço é buscado no ViaCEP)"
        , fsTooltip = Nothing, fsId = Nothing, fsName = Nothing
        , fsAttrs = [("placeholder", "00000-000")]
        }

-- | Chama o ViaCEP e monta o registro Leitor com o endereço recebido.
montarLeitor :: LeitorDados -> Handler (Either Text Leitor)
montarLeitor d = do
    resposta <- liftIO $ buscarCep (ldCep d)
    pure $ case resposta of
        Left erro -> Left erro
        Right end -> Right Leitor
            { leitorNome       = ldNome d
            , leitorEmail      = ldEmail d
            , leitorTelefone   = ldTelefone d
            , leitorCep        = fromMaybe (ldCep d) (normalizarCep (ldCep d))
            , leitorLogradouro = endLogradouro end
            , leitorNumero     = ldNumero d
            , leitorBairro     = endBairro end
            , leitorCidade     = endCidade end
            , leitorUf         = endUf end
            }

getLeitoresR :: Handler Html
getLeitoresR = do
    leitores <- runDB $ selectList [] [Asc LeitorNome]
    defaultLayout $ do
        setTitle "Leitores"
        $(whamletFile "templates/leitores/lista.hamlet")

getLeitorR :: LeitorId -> Handler Html
getLeitorR lid = do
    leitor <- runDB $ get404 lid
    emprestimos <- runDB $ selectList [EmprestimoLeitorId ==. lid] [Desc EmprestimoDataEmprestimo]
    historico <- forM emprestimos $ \(Entity _ e) -> do
        livro <- runDB $ getJust (emprestimoLivroId e)
        pure (e, livro)
    defaultLayout $ do
        setTitle (toHtml (leitorNome leitor))
        $(whamletFile "templates/leitores/detalhes.hamlet")

getLeitorNovoR :: Handler Html
getLeitorNovoR = do
    (widget, enctype) <- generateFormPost (leitorForm Nothing)
    paginaFormulario "Novo leitor" LeitorNovoR LeitoresR widget enctype

postLeitorNovoR :: Handler Html
postLeitorNovoR = do
    ((resultado, widget), enctype) <- runFormPost (leitorForm Nothing)
    let voltarAoForm = paginaFormulario "Novo leitor" LeitorNovoR LeitoresR widget enctype
    case resultado of
        FormSuccess dados -> do
            montado <- montarLeitor dados
            case montado of
                Left erro -> msgErro erro >> voltarAoForm
                Right leitor -> do
                    inserido <- runDB $ insertUnique leitor
                    case inserido of
                        Just lid -> do
                            msgSucesso "Leitor cadastrado com endereço obtido do ViaCEP."
                            redirect (LeitorR lid)
                        Nothing -> msgErro "Já existe um leitor com esse e-mail." >> voltarAoForm
        _ -> voltarAoForm

getLeitorEditarR :: LeitorId -> Handler Html
getLeitorEditarR lid = do
    leitor <- runDB $ get404 lid
    (widget, enctype) <- generateFormPost (leitorForm (Just leitor))
    paginaFormulario "Editar leitor" (LeitorEditarR lid) (LeitorR lid) widget enctype

postLeitorEditarR :: LeitorId -> Handler Html
postLeitorEditarR lid = do
    leitor <- runDB $ get404 lid
    ((resultado, widget), enctype) <- runFormPost (leitorForm (Just leitor))
    let voltarAoForm = paginaFormulario "Editar leitor" (LeitorEditarR lid) (LeitorR lid) widget enctype
    case resultado of
        FormSuccess dados -> do
            montado <- montarLeitor dados
            case montado of
                Left erro -> msgErro erro >> voltarAoForm
                Right novo -> do
                    existente <- runDB $ getBy (UniqueLeitorEmail (leitorEmail novo))
                    case existente of
                        Just (Entity outroId _) | outroId /= lid ->
                            msgErro "Já existe um leitor com esse e-mail." >> voltarAoForm
                        _ -> do
                            runDB $ replace lid novo
                            msgSucesso "Leitor atualizado."
                            redirect (LeitorR lid)
        _ -> voltarAoForm

postLeitorExcluirR :: LeitorId -> Handler Html
postLeitorExcluirR lid = do
    _ <- runDB $ get404 lid
    qtd <- runDB $ count [EmprestimoLeitorId ==. lid]
    if qtd > 0
        then do
            msgErro "Não é possível excluir: o leitor possui empréstimos registrados."
            redirect (LeitorR lid)
        else do
            runDB $ delete lid
            msgSucesso "Leitor excluído."
            redirect LeitoresR
