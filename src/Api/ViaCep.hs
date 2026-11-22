-- | Integração com a API externa ViaCEP (https://viacep.com.br).
-- Recebe um CEP, faz uma requisição HTTP GET e devolve o endereço.
-- Exemplo de resposta da API:
--   GET https://viacep.com.br/ws/01001000/json/
--   { "cep": "01001-000", "logradouro": "Praça da Sé",
--     "bairro": "Sé", "localidade": "São Paulo", "uf": "SP", ... }
-- Quando o CEP não existe a API responde: { "erro": true }
module Api.ViaCep
    ( Endereco (..)
    , buscarCep
    , normalizarCep
    ) where

import Control.Exception (SomeException, try)
import Data.Aeson (FromJSON (..), Value, eitherDecode, withObject, (.:), (.:?))
import Data.Aeson.Types (Parser)
import Data.Char (isDigit)
import Data.Text (Text)
import qualified Data.Text as T
import Network.HTTP.Simple
    (getResponseBody, getResponseStatusCode, httpLBS, parseRequest)

-- | Só os campos da resposta que a aplicação usa.
data Endereco = Endereco
    { endLogradouro :: Text
    , endBairro     :: Text
    , endCidade     :: Text
    , endUf         :: Text
    } deriving Show

-- | Converte o JSON do ViaCEP para o tipo Endereco.
instance FromJSON Endereco where
    parseJSON = withObject "Endereco" $ \o -> do
        erro <- o .:? "erro" :: Parser (Maybe Value)
        case erro of
            Just _  -> fail "CEP não encontrado"
            Nothing -> Endereco
                <$> o .: "logradouro"
                <*> o .: "bairro"
                <*> o .: "localidade"
                <*> o .: "uf"

-- | Aceita "01001-000" ou "01001000" e devolve só os 8 dígitos.
normalizarCep :: Text -> Maybe Text
normalizarCep cep
    | T.all (\c -> isDigit c || c == '-') limpo && T.length digitos == 8 = Just digitos
    | otherwise = Nothing
  where
    limpo   = T.strip cep
    digitos = T.filter isDigit limpo

-- | Consulta o ViaCEP. Left = mensagem de erro, Right = endereço.
buscarCep :: Text -> IO (Either Text Endereco)
buscarCep cepDigitado =
    case normalizarCep cepDigitado of
        Nothing  -> pure (Left "CEP inválido: informe 8 dígitos (ex.: 01001-000).")
        Just cep -> do
            resultado <- try $ do
                req  <- parseRequest ("https://viacep.com.br/ws/" <> T.unpack cep <> "/json/")
                resp <- httpLBS req
                pure (getResponseStatusCode resp, getResponseBody resp)
            pure $ case resultado of
                Left (_ :: SomeException) ->
                    Left "Não foi possível consultar o ViaCEP. Verifique a conexão e tente novamente."
                Right (200, corpo) ->
                    case eitherDecode corpo of
                        Right endereco -> Right endereco
                        Left _         -> Left "CEP não encontrado."
                Right (status, _) ->
                    Left ("O ViaCEP respondeu com erro (HTTP " <> T.pack (show status) <> ").")
