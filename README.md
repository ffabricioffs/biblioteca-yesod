# 📚 Biblioteca — Projeto Final Yesod (Haskell)

## 1. Descrição

**Aplicação online:** https://biblioteca-yesod.vercel.app

Sistema web para gerenciar uma biblioteca: acervo de livros (com autores, editoras e categorias), cadastro de leitores e controle de empréstimos e devoluções.

**Principais funcionalidades**
- CRUD completo de **categorias, editoras, autores, livros, leitores e empréstimos**
- Livro com **vários autores** (relacionamento N:N)
- Controle de **exemplares disponíveis**: não deixa emprestar sem estoque
- Registro de **devolução** e destaque de empréstimos **atrasados**
- **Endereço do leitor preenchido automaticamente pelo CEP** (API ViaCEP)
- Busca de livros por título, filtros de empréstimos (em andamento/atrasados) e painel com totais
- Validação de formulários (campos obrigatórios, e-mail, CEP, ano, quantidade, datas) e proteção contra exclusões que quebrariam chaves estrangeiras

**Arquitetura:** Opção A, aplicação **monolítica** com Yesod e Shakespearean Templates (Hamlet + Lucius).

## 2. Tecnologias

| Item | Tecnologia |
|---|---|
| Linguagem / framework | Haskell, Yesod 1.6 (yesod-core, yesod-form) |
| Templates | Hamlet (HTML) e Lucius (CSS) |
| Banco de dados | PostgreSQL, com Persistent / persistent-postgresql (ORM e migrações) |
| Cliente HTTP / JSON | http-conduit e aeson |
| API externa | [ViaCEP](https://viacep.com.br) |
| Build | Stack ou Cabal; Docker para hospedagem |

## 3. Como executar

A aplicação lê duas variáveis de ambiente:

| Variável | Padrão |
|---|---|
| `DATABASE_URL` | `postgresql://biblio:biblio@localhost:5432/biblioteca` |
| `PORT` | `3000` |
| `SESSION_KEY` | sem valor: a chave da sessão é gerada no arquivo `client_session_key.aes` |

As tabelas são criadas automaticamente na inicialização (`runMigration migrateAll`).

### Opção 1: Docker Compose (não precisa instalar Haskell)
```bash
docker compose up --build
```
Acesse http://localhost:3000. O compose sobe o PostgreSQL e a aplicação.

### Opção 2: Stack (desenvolvimento)
1. Instale o [Stack](https://docs.haskellstack.org) e o PostgreSQL (ou suba só o banco com `docker compose up db`).
2. Crie o banco (se não usar o compose):
   ```sql
   CREATE USER biblio WITH PASSWORD 'biblio';
   CREATE DATABASE biblioteca OWNER biblio;
   ```
3. Compile e rode:
   ```bash
   stack build
   stack exec biblioteca
   ```
> **Windows:** o pacote `persistent-postgresql` precisa da `libpq`. Instale com `stack exec -- pacman -S mingw-w64-x86_64-postgresql` ou use o WSL / Docker Compose.

### Hospedagem (Vercel + Neon)
A aplicação roda no **Container Runtime** do Vercel, que constrói a imagem a partir do `Dockerfile` da raiz. O banco fica no **Neon** (PostgreSQL gratuito).

1. Crie um banco no [Neon](https://neon.com) e copie a *connection string* (`postgresql://...?sslmode=require`).
2. No [Vercel](https://vercel.com): **Add New → Project**, importe o repositório. O Vercel detecta o `Dockerfile`.
3. Em *Environment Variables*, defina:
   - `DATABASE_URL`: a string do Neon;
   - `PORT`: `3000`, a porta em que o app escuta;
   - `SESSION_KEY`: uma chave aleatória (`head -c 96 /dev/urandom | base64 -w0`). Ela é necessária porque o Vercel pode rodar várias instâncias, e todas precisam da mesma chave para validar os formulários.
4. Faça o deploy. Cada `git push` na branch principal publica uma nova versão.

## 4. Banco de dados (7 tabelas)

Definidas em `config/models`.

| Tabela | Descrição | Relacionamentos |
|---|---|---|
| `categoria` | Gênero/assunto do livro (nome único) | 1:N com `livro` |
| `editora` | Editora que publica o livro (nome único) | 1:N com `livro` |
| `autor` | Autores das obras | N:N com `livro` via `livro_autor` |
| `livro` | Título, ISBN, ano e quantidade de exemplares | FK `editora_id`, FK `categoria_id` |
| `livro_autor` | Associação entre livros e autores (par único) | FK `livro_id`, FK `autor_id` |
| `leitor` | Dados do leitor e endereço vindo do ViaCEP (e-mail único) | 1:N com `emprestimo` |
| `emprestimo` | Datas de empréstimo, prevista e de devolução (`NULL` = em aberto) | FK `livro_id`, FK `leitor_id` |

```
categoria 1──N livro N──1 editora
                │ 1
                N
          livro_autor N──1 autor
livro 1──N emprestimo N──1 leitor
```

## 5. Integração com API

**ViaCEP** (`https://viacep.com.br/ws/{cep}/json/`), usada em `src/Api/ViaCep.hs`.
No cadastro e na edição de leitor, o usuário informa só o **CEP** e o **número**. A aplicação consulta o ViaCEP e grava **logradouro, bairro, cidade e UF** retornados no banco. Esses dados aparecem na listagem (cidade/UF) e na página do leitor. CEP inexistente, CEP mal formatado e falha de rede são tratados com mensagens de erro.

## 6. Integrantes

| Nome | Contribuições |
|---|---|
| Fabrício Ferreira da Silva | Modelagem do banco, CRUDs, integração com ViaCEP, templates e deploy (Neon + Vercel) |

## Estrutura do código

```
app/Main.hs              conexão com o banco, migração e servidor
config/models            definição das 7 tabelas (Persistent)
config/routes            rotas da aplicação
src/Foundation.hs        tipo App, layout padrão, acesso ao banco
src/Application.hs       liga as rotas aos handlers
src/Models.hs            gera os tipos a partir de config/models
src/Api/ViaCep.hs        cliente da API ViaCEP
src/Handler/*.hs         um módulo por entidade (CRUD)
templates/               Hamlet (páginas) e Lucius (CSS)
```
