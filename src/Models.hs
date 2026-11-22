-- | Gera, a partir do arquivo config/models, os tipos Haskell
-- (Categoria, Livro, ...), as chaves (LivroId, ...), os campos de
-- filtro (LivroTitulo, EmprestimoDataDevolucao, ...) e a função
-- 'migrateAll', que cria/atualiza as tabelas no PostgreSQL.
module Models where

import Data.Text (Text)
import Data.Time (Day)
import Database.Persist.Quasi (lowerCaseSettings)
import Database.Persist.TH

share [mkPersist sqlSettings, mkMigrate "migrateAll"]
    $(persistFileWith lowerCaseSettings "config/models")
