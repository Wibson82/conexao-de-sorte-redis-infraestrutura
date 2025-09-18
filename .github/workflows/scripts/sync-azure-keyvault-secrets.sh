#!/bin/bash

# ================================================================================
# 🔐 AZURE KEY VAULT SECRETS SYNC SCRIPT
# ================================================================================
# Este script obtém secrets do Azure Key Vault usando GitHub OIDC e cria
# Docker Secrets no Docker Swarm para uso seguro pelos containers
#
# Uso: ./sync-azure-keyvault-secrets.sh <vault-name> <environment>
# Exemplo: ./sync-azure-keyvault-secrets.sh kv-conexao-de-sorte production
# ================================================================================

set -euo pipefail

# Configuração de cores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging com cores
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar parâmetros
if [[ $# -ne 2 ]]; then
    log_error "Uso: $0 <vault-name> <environment>"
    log_error "Exemplo: $0 kv-conexao-de-sorte production"
    exit 1
fi

VAULT_NAME="$1"
ENVIRONMENT="$2"
RETRY_ATTEMPTS=3
RETRY_DELAY=10

log_info "🔐 Iniciando sincronização de secrets do Azure Key Vault"
log_info "📦 Vault: $VAULT_NAME"
log_info "🌍 Environment: $ENVIRONMENT"

# ================================================================================
# DEFINIR MAPEAMENTO DE SECRETS
# ================================================================================

# Redis Infrastructure Secrets - Apenas os necessários para funcionamento do Redis
declare -A REDIS_SECRETS=(
    ["conexao-de-sorte-redis-password"]="REDIS_PASSWORD"
    ["conexao-de-sorte-redis-host"]="REDIS_HOST"
    ["conexao-de-sorte-redis-port"]="REDIS_PORT"
    ["conexao-de-sorte-redis-database"]="REDIS_DATABASE"
)

# ================================================================================
# FUNÇÕES AUXILIARES
# ================================================================================

# Função para obter secret do Key Vault com retry
get_keyvault_secret() {
    local secret_name="$1"
    local attempt=1

    while [[ $attempt -le $RETRY_ATTEMPTS ]]; do
        log_info "🔑 Obtendo secret '$secret_name' (tentativa $attempt/$RETRY_ATTEMPTS)"

        # Usar REST API diretamente com token OIDC em vez de Azure CLI
        if SECRET_VALUE=$(curl -s -f \
            -H "Authorization: Bearer $AZURE_ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            "https://${VAULT_NAME}.vault.azure.net/secrets/${secret_name}?api-version=7.4" \
            | jq -r '.value' 2>/dev/null); then

            if [[ -n "$SECRET_VALUE" && "$SECRET_VALUE" != "null" ]]; then
                log_success "Secret '$secret_name' obtido com sucesso"
                echo "$SECRET_VALUE"
                return 0
            fi
        fi

        log_warning "Tentativa $attempt falhou para secret '$secret_name'"

        if [[ $attempt -lt $RETRY_ATTEMPTS ]]; then
            log_info "Aguardando ${RETRY_DELAY}s antes da próxima tentativa..."
            sleep $RETRY_DELAY
        fi

        ((attempt++))
    done

    log_error "Falha ao obter secret '$secret_name' após $RETRY_ATTEMPTS tentativas"
    return 1
}

# Função para criar Docker Secret com cleanup
create_docker_secret() {
    local secret_name="$1"
    local secret_value="$2"

    # Verificar se secret já existe e remover
    if docker secret ls --format "table {{.Name}}" | grep -q "^${secret_name}$"; then
        log_warning "Secret Docker '$secret_name' já existe - removendo..."
        if docker secret rm "$secret_name" 2>/dev/null; then
            log_success "Secret Docker '$secret_name' removido"
        else
            log_warning "Não foi possível remover secret '$secret_name' - pode estar em uso"
        fi
    fi

    # Criar novo secret
    if echo "$secret_value" | docker secret create "$secret_name" - >/dev/null 2>&1; then
        log_success "Docker Secret '$secret_name' criado com sucesso"
        return 0
    else
        log_error "Falha ao criar Docker Secret '$secret_name'"
        return 1
    fi
}

# Função para processar um grupo de secrets
process_secret_group() {
    local -n secrets_map=$1
    local group_name="$2"
    local failed_secrets=()

    log_info "📋 Processando grupo de secrets: $group_name"

    for keyvault_secret in "${!secrets_map[@]}"; do
        docker_secret="${secrets_map[$keyvault_secret]}"

        if secret_value=$(get_keyvault_secret "$keyvault_secret"); then
            if create_docker_secret "$docker_secret" "$secret_value"; then
                log_success "✅ $keyvault_secret → $docker_secret"
            else
                failed_secrets+=("$keyvault_secret")
            fi
        else
            failed_secrets+=("$keyvault_secret")
        fi
    done

    if [[ ${#failed_secrets[@]} -gt 0 ]]; then
        log_error "❌ Falha ao processar secrets do grupo '$group_name': ${failed_secrets[*]}"
        return 1
    else
        log_success "✅ Todos os secrets do grupo '$group_name' processados com sucesso"
        return 0
    fi
}

# ================================================================================
# OBTER TOKEN DE ACESSO AZURE VIA OIDC
# ================================================================================

log_info "🔐 Obtendo token de acesso Azure via GitHub OIDC..."

# Verificar se variáveis de ambiente necessárias estão definidas
required_vars=("AZURE_CLIENT_ID" "AZURE_TENANT_ID" "ACTIONS_ID_TOKEN_REQUEST_TOKEN" "ACTIONS_ID_TOKEN_REQUEST_URL")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        log_error "Variável de ambiente '$var' não está definida"
        exit 1
    fi
done

# Obter token OIDC do GitHub
log_info "🎫 Obtendo token OIDC do GitHub Actions..."
GITHUB_TOKEN=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" \
    | jq -r '.value')

if [[ -z "$GITHUB_TOKEN" || "$GITHUB_TOKEN" == "null" ]]; then
    log_error "Falha ao obter token OIDC do GitHub"
    exit 1
fi

log_success "Token OIDC do GitHub obtido com sucesso"

# Trocar token OIDC por token de acesso Azure
log_info "🔄 Trocando token OIDC por token de acesso Azure..."
AZURE_ACCESS_TOKEN=$(curl -s -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "scope=https://vault.azure.net/.default" \
    -d "client_id=$AZURE_CLIENT_ID" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    -d "client_assertion=$GITHUB_TOKEN" \
    -d "grant_type=client_credentials" \
    "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
    | jq -r '.access_token')

if [[ -z "$AZURE_ACCESS_TOKEN" || "$AZURE_ACCESS_TOKEN" == "null" ]]; then
    log_error "Falha ao obter token de acesso Azure"
    exit 1
fi

log_success "Token de acesso Azure obtido com sucesso"

# ================================================================================
# PROCESSAR SECRETS
# ================================================================================

log_info "🚀 Iniciando processamento de secrets..."

# Variáveis para controle de sucesso
redis_success=false

# Processar Redis secrets
if process_secret_group REDIS_SECRETS "Redis Infrastructure"; then
    redis_success=true
fi

# ================================================================================
# VALIDAÇÃO FINAL
# ================================================================================

log_info "🔍 Validando secrets criados..."

# Listar todos os secrets criados
log_info "📋 Secrets Docker criados:"
docker secret ls --format "table {{.Name}}\t{{.CreatedAt}}" | grep -E "REDIS_" || true

# Verificar se pelo menos os secrets essenciais foram criados
essential_secrets=("REDIS_PASSWORD")
missing_essential=()

for secret in "${essential_secrets[@]}"; do
    if ! docker secret ls --format "{{.Name}}" | grep -q "^${secret}$"; then
        missing_essential+=("$secret")
    fi
done

# ================================================================================
# RELATÓRIO FINAL
# ================================================================================

log_info "📊 RELATÓRIO DE SINCRONIZAÇÃO"
echo "============================================================"
echo "🕒 Timestamp: $(date)"
echo "📦 Vault: $VAULT_NAME"
echo "🌍 Environment: $ENVIRONMENT"
echo ""

if [[ $redis_success == true ]]; then
    log_success "✅ Redis Infrastructure secrets: OK"
else
    log_error "❌ Redis Infrastructure secrets: FALHA"
fi

if [[ ${#missing_essential[@]} -eq 0 ]]; then
    log_success "✅ Todos os secrets essenciais foram criados"
    echo ""
    log_success "🎉 Sincronização do Redis concluída com sucesso!"
    exit 0
else
    log_error "❌ Secrets essenciais não criados: ${missing_essential[*]}"
    echo ""
    log_error "💥 Sincronização falhou!"
    exit 1
fi