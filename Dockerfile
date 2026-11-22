# ---------- Etapa 1: compilação ----------
# Usa as bibliotecas Haskell já empacotadas no Ubuntu 24.04 (GHC 9.4 +
# Yesod 1.6). Assim só o código do projeto é compilado: build rápido.
FROM ubuntu:24.04 AS build
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
        ghc cabal-install libpq-dev zlib1g-dev \
        libghc-yesod-dev libghc-yesod-form-dev \
        libghc-persistent-postgresql-dev libghc-http-conduit-dev \
        libghc-aeson-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
# Config vazia do cabal: compila só com os pacotes instalados acima.
RUN mkdir -p /root/.cabal && touch /root/.cabal/config \
    && cabal build --offline \
    && cp "$(cabal list-bin biblioteca --offline 2>/dev/null)" /app/biblioteca-bin

# ---------- Etapa 2: imagem final (só o executável) ----------
FROM ubuntu:24.04
ENV LANG=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 libgmp10 libffi8 zlib1g libyaml-0-2 ca-certificates netbase \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/biblioteca-bin /app/biblioteca
# O Yesod grava a chave da sessão (client_session_key.aes) em /app.
ENV PORT=3000
EXPOSE 3000
CMD ["/app/biblioteca"]
