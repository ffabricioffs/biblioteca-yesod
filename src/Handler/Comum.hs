-- | Funções auxiliares usadas por vários handlers.
module Handler.Comum where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time
import Database.Persist.Sql (fromSqlKey)
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

-- | Número com a palavra no singular ou no plural: "1 título", "3 títulos".
contagem :: Int -> Text -> Text -> Text
contagem n singular plural = T.pack (show n) <> " " <> (if n == 1 then singular else plural)

-- | Data por extenso em português, ex.: "Domingo, 22 de novembro de 2026".
dataPorExtenso :: Day -> Text
dataPorExtenso d = T.concat [semana, ", ", T.pack (show dia), " de ", mes, " de ", T.pack (show ano)]
  where
    (ano, m, dia) = toGregorian d
    mes = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
           "agosto", "setembro", "outubro", "novembro", "dezembro"] !! (m - 1)
    semana = case dayOfWeek d of
        Sunday    -> "Domingo"
        Monday    -> "Segunda-feira"
        Tuesday   -> "Terça-feira"
        Wednesday -> "Quarta-feira"
        Thursday  -> "Quinta-feira"
        Friday    -> "Sexta-feira"
        Saturday  -> "Sábado"

-- | Situação de um empréstimo em relação à data de hoje.
--   Devolve (texto, classe CSS).
statusEmprestimo :: Day -> Emprestimo -> (Text, Text)
statusEmprestimo dia e = case emprestimoDataDevolucao e of
    Just _ -> ("Devolvido", "ok")
    Nothing
        | dia > emprestimoDataPrevista e -> ("Atrasado", "atrasado")
        | otherwise                      -> ("Em andamento", "andamento")

-- | Cor da lombada do livro na estante: depende da categoria, então
-- livros da mesma categoria ficam com a mesma cor de encadernação.
corLombada :: Livro -> Text
corLombada livro = cores !! fromIntegral (fromSqlKey (livroCategoriaId livro) `mod` 7)
  where
    cores = ["#6E2B2B", "#24493A", "#22324F", "#8A6420", "#4F3048", "#3E4A4F", "#7A3E22"]

-- | Altura e largura da lombada (em pixels), variando com o título
-- para a estante não ficar com todos os livros iguais.
alturaLombada, larguraLombada :: Livro -> Int
alturaLombada livro = 150 + (T.length (livroTitulo livro) * 13) `mod` 55
larguraLombada livro = 34 + min 18 (T.length (livroTitulo livro) `div` 3)
