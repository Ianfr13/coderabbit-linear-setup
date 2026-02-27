# CodeRabbit → Linear Issue (Auto Setup)

Workflow do GitHub Actions que automatiza a criação de issues no Linear a partir dos reviews do CodeRabbit.

## Como Funciona

```
PR aberto → CodeRabbit faz review → Walkthrough postado →
GitHub Actions detecta → Aguarda 10min → Analisa findings →
Comenta pedindo issue consolidado → CodeRabbit cria issue no Linear
```

### Fluxo detalhado

1. **Trigger**: CodeRabbit posta/edita um comentário com `walkthrough_start` em um PR
2. **Espera**: Aguarda 10 minutos para o review completo ser finalizado
3. **Filtragem**: Verifica se há findings significativos (⚠️, 🔴, changes requested, etc.)
4. **Deduplicação**: Checa se já foi solicitado um issue nesse PR (evita duplicatas)
5. **Ação**: Posta um comentário pedindo ao CodeRabbit para criar UM issue consolidado no Linear com todos os findings

## Setup Rápido

### 1. Copiar o Workflow

Copie o arquivo [`coderabbit-linear-issue.yml`](./coderabbit-linear-issue.yml) para `.github/workflows/` no seu repositório.

### 2. Configurar PAT_TOKEN

O workflow usa um **Personal Access Token** (não o GITHUB_TOKEN padrão) para ter permissão de comentar em PRs e triggerar outros workflows.

1. Vá em [github.com/settings/tokens](https://github.com/settings/tokens)
2. Crie um **Fine-grained token** com:
   - **Repository access**: Todos os repos que usarão o workflow
   - **Permissions**:
     - `Issues`: Read and Write
     - `Pull requests`: Read and Write
     - `Contents`: Read
3. No repositório, vá em **Settings → Secrets and variables → Actions**
4. Crie um secret chamado `PAT_TOKEN` com o token gerado

### 3. Configurar CodeRabbit

Certifique-se de que o [CodeRabbit](https://coderabbit.ai) está instalado e configurado no repositório. O workflow depende do bot `coderabbitai[bot]` postar comentários de walkthrough.

### 4. Configurar Linear Integration no CodeRabbit

Para que o CodeRabbit possa criar issues no Linear:
1. Acesse o [dashboard do CodeRabbit](https://app.coderabbit.ai)
2. Conecte sua conta do Linear
3. Configure o projeto/time onde os issues serão criados

## Instalação via API (Automático)

Para adicionar o workflow a um repo via CLI:

```bash
# Encode o arquivo
CONTENT=$(base64 < coderabbit-linear-issue.yml)

# Push para o repo
gh api "repos/OWNER/REPO/contents/.github/workflows/coderabbit-linear-issue.yml" \
  --method PUT \
  --field message="ci: add CodeRabbit → Linear auto-issue workflow" \
  --field content="$CONTENT"
```

Para atualizar um repo que já tem o workflow:

```bash
# Pegar SHA atual
SHA=$(gh api "repos/OWNER/REPO/contents/.github/workflows/coderabbit-linear-issue.yml" --jq '.sha')
CONTENT=$(base64 < coderabbit-linear-issue.yml)

# Update
gh api "repos/OWNER/REPO/contents/.github/workflows/coderabbit-linear-issue.yml" \
  --method PUT \
  --field message="ci: update CodeRabbit → Linear workflow" \
  --field content="$CONTENT" \
  --field sha="$SHA"
```

## Repos com o Workflow Instalado

| Repositório | Status |
|---|---|
| sales-brain | ✅ Origem (latest) |
| creative-studio | ✅ Atualizado |
| Axon.MCP.Server | ✅ Instalado |
| mcp-router | ✅ Instalado |
| brain-crm | ✅ Instalado |
| claude-brain | ✅ Instalado |
| ai-manus | ✅ Instalado |
| code-workflow | ✅ Instalado |
| ad-radar | ✅ Instalado |
| video-downloader | ✅ Instalado |
| traffic-manager-plugin | ✅ Instalado |
| media-forge | ✅ Instalado |
| douravita-social-engine | ✅ Instalado |
| dashboard-metas-vendas | ✅ Instalado |
| agrovio-ia | ✅ Instalado |

## Personalização

### Tempo de espera

O `sleep 600` (10 minutos) pode ser ajustado. É o tempo para o CodeRabbit finalizar o review completo antes de analisar os findings.

### Critérios de findings

Atualmente detecta findings por:
- Emojis de alerta: ⚠️, 🔴
- Texto: "Changes requested", "needs attention"
- Tamanho do walkthrough: > 2000 caracteres

Edite a seção `hasFindings` no workflow para ajustar.

## Troubleshooting

| Problema | Solução |
|---|---|
| Workflow não triggera | Verifique se CodeRabbit está postando comentários com `walkthrough_start` |
| Erro de permissão | Verifique se `PAT_TOKEN` tem permissões corretas |
| Issue duplicado | O workflow já tem proteção contra duplicatas |
| Review incompleto | Aumente o `sleep` se o CodeRabbit demora mais de 10min |
| Linear não conectado | Configure a integração Linear no dashboard do CodeRabbit |
