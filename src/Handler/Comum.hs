-- | Funções auxiliares usadas por vários handlers.
module Handler.Comum where

import Data.Text (Text)
import Data.Time
import Yesod

import Foundation
import Models

-- | Data de hoje no fuso de Brasília (UTC-3).
hoje :: Handler Day
hoje = do
    agora <- liftIO getCurrentTime
    pure $ localDay (utcToLocalTime (hoursToTimeZone (-3)) agora)

-- | Mensagens exibidas no topo da próxima página (verde / vermelha).
msgSucesso :: Text -> Handler ()
msgSucesso t = setMessage [shamlet|<div .msg .sucesso>#{t}|]

msgErro :: Text -> Handler ()
msgErro t = setMessage [shamlet|<div .msg .erro>#{t}|]

-- | Página genérica de formulário, reaproveitada em todos os cadastros.
--   titulo: texto do cabeçalho; acao: rota que recebe o POST;
--   voltar: rota do botão "Cancelar".
paginaFormulario :: Text -> Route App -> Route App -> Widget -> Enctype -> Handler Html
paginaFormulario titulo acao voltar formWidget enctype =
    defaultLayout $ do
        setTitle (toHtml titulo)
        $(whamletFile "templates/formulario.hamlet")

-- | Formata uma data como dd/mm/aaaa.
formatarData :: Day -> String
formatarData = formatTime defaultTimeLocale "%d/%m/%Y"

-- | Situação de um empréstimo em relação à data de hoje.
--   Devolve (texto, classe CSS).
statusEmprestimo :: Day -> Emprestimo -> (Text, Text)
statusEmprestimo dia e = case emprestimoDataDevolucao e of
    Just _ -> ("Devolvido", "ok")
    Nothing
        | dia > emprestimoDataPrevista e -> ("Atrasado", "atrasado")
        | otherwise                      -> ("Em andamento", "andamento")
