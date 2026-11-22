{-# OPTIONS_GHC -fno-warn-orphans #-}
-- | Liga cada rota de config/routes ao seu handler. Por isso este
-- módulo importa TODOS os handlers. (A definição das rotas fica em
-- Foundation.hs; separar as duas coisas evita importação circular.)
module Application where

import Yesod

import Foundation
import Handler.Autor
import Handler.Categoria
import Handler.Editora
import Handler.Home
import Handler.Livro

mkYesodDispatch "App" resourcesApp
