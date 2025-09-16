#!/bin/bash

# ============================================================================
# 🔐 AZURE KEY VAULT TO REDIS SECRETS SYNC SCRIPT
# ============================================================================
#
# Script simplificado para sincronizar apenas o secret Redis do Azure Key Vault
# Baseado no script da infraestrutura core mas otimizado para Redis
#
# Uso: ./sync-redis-secrets.sh [VAULT_NAME]
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

VAULT_NAME="${1:-kv-conexao-de-sorte}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

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

log_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_prerequisites() {
    log_step "Verificando pré-requisitos..."

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI não encontrado"
        exit 1
    fi

    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Azure CLI não está logado"
        exit 1
    fi

    # Check Key Vault access
    if ! az keyvault show --name "$VAULT_NAME" &> /dev/null; then
        log_error "Não é possível acessar o Azure Key Vault: $VAULT_NAME"
        exit 1
    fi

    log_success "Pré-requisitos verificados"
}

# ============================================================================
# SECRET MANAGEMENT
# ============================================================================

get_redis_password() {
    log_step "Buscando senha Redis do Azure Key Vault..."

    local secret_value
    if secret_value=$(az keyvault secret show \
        --vault-name "$VAULT_NAME" \
        --name "conexao-de-sorte-redis-password" \
        --query value \
        --output tsv 2>/dev/null); then

        if [[ -n "$secret_value" && "$secret_value" != "null" && "$secret_value" != "" ]]; then
            log_success "Senha Redis obtida com sucesso"
            echo "$secret_value"
            return 0
        else
            log_error "Senha Redis está vazia ou é null"
            return 1
        fi
    else
        log_error "Secret 'conexao-de-sorte-redis-password' não encontrado no Key Vault"
        return 1
    fi
}

create_env_file() {
    local redis_password="$1"

    log_step "Criando arquivo .env com senha segura..."

    cat > .env << EOF
# Senha Redis obtida do Azure Key Vault
REDIS_PASSWORD=$redis_password
EOF

    log_success "Arquivo .env criado com senha segura"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "============================================================================"
    echo "🔐 REDIS SECRET SYNC SCRIPT"
    echo "============================================================================"
    echo "Vault: $VAULT_NAME"
    echo "============================================================================"

    check_prerequisites

    # Obter senha Redis do Azure Key Vault
    local redis_password
    if redis_password=$(get_redis_password); then
        create_env_file "$redis_password"
        log_success "✅ Sincronização de secret Redis concluída com SUCESSO"
        return 0
    else
        log_error "❌ FALHA ao obter senha Redis do Azure Key Vault"
        exit 1
    fi
}

# Execute main function
main "$@"