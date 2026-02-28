# CodeRabbit → Linear (Full Automation)

Pipeline completo que conecta code reviews do CodeRabbit ao Linear com gerenciamento automático de issues. Zero intervenção — configure uma vez e tudo roda sozinho pra sempre, incluindo repos novos.

## Como Funciona

```
PR aberto → CodeRabbit review → Polling até estabilizar →
Análise por score → Labels no PR → Issue criado no Linear (Triage) →
PR avança → Issue move automaticamente → PR merged → Issue Done
```

### Pipeline Completo

1. **Trigger** — CodeRabbit posta walkthrough em um PR
2. **Polling inteligente** — Monitora a cada 60s até o review estabilizar (máx 15 min)
3. **Análise por score** — Avalia findings com pontuação ponderada. Score >= 3 cria issue
4. **Labels GitHub** — Aplica labels automáticas no PR (security, bug, performance, severity)
5. **Issue no Linear** — Cria via API com título, descrição, prioridade, labels, projeto e status inicial (Triage)
6. **Lifecycle sync** — Acompanha o PR e atualiza o issue no Linear automaticamente:

| Evento no PR | Status no Linear |
|---|---|
| PR aberto / reaberto | In Progress |
| Review com changes requested | In Progress |
| Review aprovado | **Ready to Merge** |
| PR merged | Done (com comentário) |
| PR fechado sem merge | Cancelled (com motivo) |

7. **Repos novos** — Qualquer repo novo criado na sua conta recebe os workflows automaticamente

### Detecção de Findings

| Sinal | Score | Exemplos |
|-------|-------|----------|
| Segurança | +5 | security, vulnerability, injection, xss, csrf |
| Crítico | +5 | emoji 🔴 |
| Changes requested | +4 | "Changes requested" no walkthrough |
| Alerta | +3 | emoji ⚠️, "needs attention" |
| Bug potencial | +3 | bug, error, crash, exception |
| Performance | +2 | memory leak, N+1, slow |
| Tamanho (bônus) | +1 | walkthrough > 3000 chars (só com outros sinais) |

### Labels Automáticas no PR

| Label | Quando | Cor |
|-------|--------|-----|
| `coderabbit-review` | Sempre | Roxo |
| `security` | Vulnerabilidade detectada | Vermelho |
| `bug` | Bug/error/crash | Vermelho claro |
| `performance` | Memory leak, N+1, slow | Amarelo |
| `critical` | Emoji 🔴 | Vermelho escuro |
| `changes-requested` | Changes requested | Laranja |
| `severity:urgent/high/medium` | Baseado no score | Gradiente |

### Issue no Linear

O issue é criado diretamente via API com:
- Título: `[CodeRabbit] repo#PR: título do PR`
- Descrição: repo, PR link, branch, autor, arquivos alterados, checklist
- Prioridade: Urgent (score>=8), High (score>=5), Medium (score>=3)
- Labels: baseadas nos sinais detectados (Security, Bug, Performance, etc.)
- Projeto: atribuído automaticamente se `LINEAR_PROJECT_ID` configurado
- Status: Triage → In Progress → Ready to Merge → Done (automático)

## Setup (uma vez)

### 1. Secrets necessários

Configure em **cada repo** ou use o auto-sync (recomendado):

| Secret | Onde criar | Descrição |
|--------|-----------|-----------|
| `PAT_TOKEN` | [GitHub Tokens](https://github.com/settings/tokens) | Fine-grained: Issues + PRs + Contents (Read/Write) |
| `LINEAR_API_KEY` | [Linear Settings → API](https://linear.app/settings/api) | Personal API key |
| `LINEAR_TEAM_ID` | Linear → Settings → Team | ID do time (UUID) |
| `LINEAR_PROJECT_ID` | Linear → Project → Settings | ID do projeto (opcional) |

### 2. CodeRabbit + Linear

1. Instale o [CodeRabbit](https://coderabbit.ai) nos repos
2. No [dashboard do CodeRabbit](https://app.coderabbit.ai), conecte o Linear

### 3. Deploy

**Automático (recomendado):** Faça push neste repo → workflows deployados em todos os repos de `repos.json`.

**Repos novos:** O workflow `auto-install.yml` detecta repos criados e instala tudo automaticamente.

**Manual:**
```bash
./scripts/sync.sh              # Deploy em todos
./scripts/sync.sh --check      # Verificar status
./scripts/sync.sh --dry-run    # Preview
./scripts/sync.sh repo1 repo2  # Repos específicos
```

## Repos Monitorados

Editável em [`repos.json`](./repos.json). Para adicionar: edite e faça push.

| Repositório |
|---|
| sales-brain |
| creative-studio |
| Axon.MCP.Server |
| mcp-router |
| brain-crm |
| claude-brain |
| ai-manus |
| code-workflow |
| ad-radar |
| video-downloader |
| traffic-manager-plugin |
| media-forge |
| douravita-social-engine |
| dashboard-metas-vendas |
| agrovio-ia |

## Configuração

Variáveis de ambiente nos workflows:

| Variável | Default | Workflow | Descrição |
|----------|---------|---------|-----------|
| `POLL_INTERVAL` | `60` | issue | Segundos entre cada check |
| `MAX_WAIT` | `900` | issue | Tempo máximo de polling (15 min) |
| `MIN_WALKTHROUGH_LENGTH` | `3000` | issue | Chars mínimos para bônus |

## Estrutura

```
├── coderabbit-linear-issue.yml    # Workflow: review → issue no Linear
├── linear-lifecycle.yml           # Workflow: PR events → status no Linear
├── repos.json                     # Lista de repos monitorados
├── scripts/
│   └── sync.sh                    # Deploy manual via CLI
├── .github/workflows/
│   ├── auto-sync.yml              # Auto-deploy quando faz push aqui
│   └── auto-install.yml           # Instala em repos novos automaticamente
└── README.md
```

## Troubleshooting

| Problema | Solução |
|----------|---------|
| Workflow não roda | Verifique se CodeRabbit está ativo e postando `walkthrough_start` |
| Nenhum issue criado | Score < 3 — verifique logs do Actions (score e sinais são logados) |
| Erro de permissão GitHub | Recrie `PAT_TOKEN` com Issues + PRs + Contents |
| Erro Linear API | Verifique `LINEAR_API_KEY` e `LINEAR_TEAM_ID` nos secrets |
| Issue não muda de status | Verifique se `linear-lifecycle.yml` está instalado no repo |
| Status não encontrado | Os nomes dos states devem incluir "In Progress", "Ready to Merge", "Done" |
| Auto-install não funciona | Precisa de webhook `repository` configurado (veja auto-install.yml) |
| Labels não criando no Linear | Verifique se a API key tem permissão de criar labels no time |
