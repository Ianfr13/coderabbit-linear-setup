#!/usr/bin/env bash
set -euo pipefail

# ─── CodeRabbit → Linear Workflow Sync ──────────────────────────────
# Deploya ou atualiza AMBOS workflows em todos os repos.
#
# Uso:
#   ./scripts/sync.sh              # Deploy/update em todos os repos
#   ./scripts/sync.sh --dry-run    # Mostra o que seria feito sem executar
#   ./scripts/sync.sh --check      # Verifica status de cada repo
#   ./scripts/sync.sh repo1 repo2  # Sync apenas repos específicos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG="$ROOT_DIR/repos.json"

# Workflows para sincronizar
WORKFLOW_FILES=(
  "coderabbit-linear-issue.yml"
  "linear-lifecycle.yml"
)
REMOTE_PATH=".github/workflows"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
CHECK_ONLY=false
SPECIFIC_REPOS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --check) CHECK_ONLY=true; shift ;;
    *) SPECIFIC_REPOS+=("$1"); shift ;;
  esac
done

if ! command -v gh &>/dev/null; then
  echo -e "${RED}Erro: gh CLI não encontrado. Instale: https://cli.github.com${NC}"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo -e "${RED}Erro: jq não encontrado. Instale: brew install jq${NC}"
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo -e "${RED}Erro: $CONFIG não encontrado${NC}"
  exit 1
fi

OWNER=$(jq -r '.owner' "$CONFIG")

if [[ ${#SPECIFIC_REPOS[@]} -gt 0 ]]; then
  REPOS=("${SPECIFIC_REPOS[@]}")
else
  mapfile -t REPOS < <(jq -r '.repos[].name' "$CONFIG")
fi

TOTAL=${#REPOS[@]}
DEPLOYED=0
UP_TO_DATE=0
SKIPPED=0
FAILED=0

echo ""
echo -e "${CYAN}━━━ CodeRabbit + Linear Lifecycle Sync ━━━${NC}"
echo -e "Owner: ${CYAN}$OWNER${NC}"
echo -e "Repos: ${CYAN}$TOTAL${NC}"
echo -e "Workflows: ${CYAN}${WORKFLOW_FILES[*]}${NC}"
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}[DRY RUN]${NC}"
[[ "$CHECK_ONLY" == true ]] && echo -e "${YELLOW}[CHECK ONLY]${NC}"
echo ""

sync_file() {
  local repo="$1"
  local local_file="$2"
  local remote_file="$REMOTE_PATH/$local_file"
  local local_path="$ROOT_DIR/$local_file"

  if [[ ! -f "$local_path" ]]; then
    echo -e "    ${RED}$local_file: arquivo local não encontrado${NC}"
    return 1
  fi

  local LOCAL_CONTENT
  LOCAL_CONTENT=$(base64 < "$local_path")
  local LOCAL_HASH
  LOCAL_HASH=$(shasum -a 256 "$local_path" | cut -d' ' -f1)

  local REMOTE_DATA
  REMOTE_DATA=$(gh api "repos/$OWNER/$repo/contents/$remote_file" 2>/dev/null || echo "NOT_FOUND")

  if [[ "$REMOTE_DATA" == "NOT_FOUND" ]]; then
    if [[ "$CHECK_ONLY" == true ]]; then
      echo -e "    ${YELLOW}$local_file: não instalado${NC}"
      return 2
    fi
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "    ${YELLOW}$local_file: seria instalado${NC}"
      return 2
    fi

    gh api "repos/$OWNER/$repo/contents/$remote_file" \
      --method PUT \
      --field message="ci: add $local_file" \
      --field content="$LOCAL_CONTENT" \
      --silent 2>/dev/null

    echo -e "    ${GREEN}$local_file: instalado${NC}"
    return 0
  fi

  local REMOTE_SHA
  REMOTE_SHA=$(echo "$REMOTE_DATA" | jq -r '.sha')
  local REMOTE_DECODED
  REMOTE_DECODED=$(echo "$REMOTE_DATA" | jq -r '.content' | tr -d '\n' | base64 -d 2>/dev/null || echo "")
  local REMOTE_HASH
  REMOTE_HASH=$(echo "$REMOTE_DECODED" | shasum -a 256 | cut -d' ' -f1)

  if [[ "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    echo -e "    ${GREEN}$local_file: atualizado${NC}"
    return 3
  fi

  if [[ "$CHECK_ONLY" == true ]]; then
    echo -e "    ${YELLOW}$local_file: desatualizado${NC}"
    return 2
  fi
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "    ${YELLOW}$local_file: seria atualizado${NC}"
    return 2
  fi

  gh api "repos/$OWNER/$repo/contents/$remote_file" \
    --method PUT \
    --field message="ci: update $local_file" \
    --field content="$LOCAL_CONTENT" \
    --field sha="$REMOTE_SHA" \
    --silent 2>/dev/null

  echo -e "    ${GREEN}$local_file: atualizado${NC}"
  return 0
}

for REPO in "${REPOS[@]}"; do
  echo -e "  ${CYAN}$REPO${NC}"

  if ! gh api "repos/$OWNER/$REPO" --silent 2>/dev/null; then
    echo -e "    ${RED}Repo não encontrado${NC}"
    ((FAILED++))
    continue
  fi

  repo_deployed=false
  repo_failed=false

  for WF in "${WORKFLOW_FILES[@]}"; do
    result=0
    sync_file "$REPO" "$WF" || result=$?

    case $result in
      0) repo_deployed=true ;;
      1) repo_failed=true ;;
      2) ((SKIPPED++)) ;;
      3) ((UP_TO_DATE++)) ;;
    esac
  done

  if [[ "$repo_deployed" == true ]]; then ((DEPLOYED++)); fi
  if [[ "$repo_failed" == true ]]; then ((FAILED++)); fi
done

echo ""
echo -e "${CYAN}━━━ Resultado ━━━${NC}"
echo -e "  ${GREEN}Deployados:${NC} $DEPLOYED repos"
echo -e "  ${GREEN}Já atualizados:${NC} $UP_TO_DATE workflows"
[[ $SKIPPED -gt 0 ]] && echo -e "  ${YELLOW}Pulados:${NC} $SKIPPED"
[[ $FAILED -gt 0 ]] && echo -e "  ${RED}Falhas:${NC} $FAILED"
echo ""
