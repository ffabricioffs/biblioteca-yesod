-- | "Fundação" da aplicação: o tipo App, as rotas e as instâncias
-- que dizem ao Yesod como montar o layout, como acessar o banco e
-- em que idioma mostrar as mensagens dos formulários.
module Foundation where

import Yesod
import Text.Hamlet (hamletFile)
import Text.Lucius (luciusFile)
import Yesod.Form.I18n.Portuguese (portugueseFormMessage)
import Database.Persist.Sql (ConnectionPool, SqlBackend, runSqlPool)
import System.Environment (lookupEnv)

import Models

-- | Estado global da aplicação: o pool de conexões com o PostgreSQL.
newtype App = App { appPool :: ConnectionPool }

-- | Lê config/routes e gera o tipo de rotas (Route App) e os tipos
-- Handler e Widget. A ligação rota -> handler é feita em Application.hs.
mkYesodData "App" $(parseRoutesFile "config/routes")

-- | Atalho para o tipo dos formulários usados nos handlers.
type Form a = Html -> MForm Handler (FormResult a, Widget)

instance Yesod App where
    -- Layout padrão de todas as páginas: menu, mensagens e CSS.
    defaultLayout widget = do
        mensagem <- getMessage
        -- Seção atual (primeiro pedaço da URL, ex.: "livros"), usada
        -- para destacar o item certo no menu lateral.
        rotaAtual <- getCurrentRoute
        let secao = case fmap (fst . renderRoute) rotaAtual of
                Just (primeiro : _) -> primeiro
                _                   -> ""
        pc <- widgetToPageContent $ do
            toWidget $(luciusFile "templates/layout.lucius")
            widget
        withUrlRenderer $(hamletFile "templates/layout.hamlet")

    -- Sessão (mensagens e token CSRF) guardada num cookie criptografado.
    -- Em produção a chave vem da variável SESSION_KEY, para que todas as
    -- instâncias do servidor usem a mesma; localmente fica num arquivo.
    makeSessionBackend _ = do
        chave <- lookupEnv "SESSION_KEY"
        Just <$> case chave of
            Just _  -> envClientSessionBackend 120 "SESSION_KEY"
            Nothing -> defaultClientSessionBackend 120 "client_session_key.aes"

-- | Como executar consultas: pega uma conexão do pool e roda.
instance YesodPersist App where
    type YesodPersistBackend App = SqlBackend
    runDB acao = do
        app <- getYesod
        runSqlPool acao (appPool app)

-- | Mensagens de validação dos formulários em português
-- ("Valor obrigatório", "Número inválido" etc.).
instance RenderMessage App FormMessage where
    renderMessage _ _ = portugueseFormMessage
