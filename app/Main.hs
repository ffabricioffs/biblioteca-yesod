-- | Ponto de entrada: conecta no PostgreSQL, cria/atualiza as
-- tabelas (migração) e sobe o servidor web.
module Main (main) where

import Control.Monad.Logger (runStdoutLoggingT)
import qualified Data.ByteString.Char8 as BS
import Data.Maybe (fromMaybe)
import Database.Persist.Postgresql (createPostgresqlPool, runMigration, runSqlPool)
import System.Environment (lookupEnv)
import Yesod (warp)

import Application ()   -- instâncias de despacho das rotas
import Foundation
import Models

main :: IO ()
main = do
    -- Variáveis de ambiente (usadas na hospedagem). Sem elas, usa os
    -- valores locais de desenvolvimento.
    porta <- maybe 3000 read <$> lookupEnv "PORT"
    url   <- fromMaybe "postgresql://biblio:biblio@localhost:5432/biblioteca"
                 <$> lookupEnv "DATABASE_URL"

    pool <- runStdoutLoggingT $ createPostgresqlPool (BS.pack url) 5
    runSqlPool (runMigration migrateAll) pool

    putStrLn ("Biblioteca rodando em http://localhost:" ++ show porta)
    warp porta (App pool)
