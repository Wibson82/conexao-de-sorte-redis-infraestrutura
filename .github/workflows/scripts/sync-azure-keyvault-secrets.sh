#!/bin/bash

# ============================================================================
# 🔐 AZURE KEY VAULT TO DOCKER SECRETS SYNC SCRIPT - REDIS INFRASTRUCTURE
# ============================================================================
#
# Script para sincronizar secrets do Azure Key Vault com Docker Secrets
# Versão específica para Redis Infrastructure
#
# Uso: ./sync-azure-keyvault-secrets.sh [VAULT_NAME] [SERVICE_NAME]
# ============================================================================

set -euo pipefail

# Configurar trap para limpar arquivos temporários
cleanup() {
    rm -f /tmp/docker_secrets_list_$$.txt 2>/dev/null || true
    rm -f /tmp/secrets_list.txt 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

VAULT_NAME="${1:-kv-conexao-de-sorte}"
SERVICE_NAME="${2:-redis-infraestrutura}"

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
        log_error "Azure CLI não encontrado. Instale: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker não encontrado. Instale Docker."
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon não está rodando. Inicie o Docker."
        exit 1
    fi

    # Check if Docker Swarm is initialized
    local swarm_state
    if swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null); then
        if [[ "$swarm_state" != "active" ]]; then
            log_warning "Docker Swarm não está ativo (estado: $swarm_state)"
            log_info "Tentando inicializar Docker Swarm..."
            if docker swarm init --advertise-addr 127.0.0.1 &> /dev/null; then
                log_success "Docker Swarm inicializado com sucesso"
            else
                log_error "Falha ao inicializar Docker Swarm. Execute manualmente: docker swarm init"
                exit 1
            fi
        else
            log_success "Docker Swarm está ativo"
        fi
    else
        log_error "Não foi possível verificar o estado do Docker Swarm"
        exit 1
    fi

    # Check Azure Key Vault access
    if ! az keyvault show --name "$VAULT_NAME" &> /dev/null; then
        log_error "Não é possível acessar o Azure Key Vault: $VAULT_NAME"
        log_error "Verifique se você está logado no Azure CLI e tem permissões adequadas"
        exit 1
    fi

    log_success "Todos os pré-requisitos atendidos"
}

# ============================================================================
# AZURE KEY VAULT FUNCTIONS
# ============================================================================

get_secret_from_keyvault() {
    local secret_name="$1"
    local secret_value

    if secret_value=$(az keyvault secret show \
        --vault-name "$VAULT_NAME" \
        --name "$secret_name" \
        --query "value" \
        --output tsv 2>/dev/null); then
        echo "$secret_value"
        return 0
    else
        return 1
    fi
}

# ============================================================================
# DOCKER SECRETS FUNCTIONS
# ============================================================================

create_docker_secret() {
    local secret_name="$1"
    local secret_value="$2"

    # Check if secret already exists
    if docker secret inspect "$secret_name" &> /dev/null; then
        log_info "Secret '$secret_name' já existe - removendo para atualizar"
        
        # Try to remove the secret (may fail if in use)
        if ! docker secret rm "$secret_name" 2>/dev/null; then
            log_warning "Não foi possível remover secret '$secret_name' (pode estar em uso)"
            log_info "Pulando atualização do secret '$secret_name'"
            return 1
        fi
    fi

    # Create new secret
    if echo "$secret_value" | docker secret create "$secret_name" - &> /dev/null; then
        log_success "Secret '$secret_name' criado com sucesso"
        return 0
    else
        log_error "Falha ao criar secret '$secret_name'"
        return 1
    fi
}

# ============================================================================
# MAIN SYNC FUNCTION
# ============================================================================

sync_secrets() {
    log_step "Sincronizando secrets do Azure Key Vault para Docker Secrets..."
    log_info "Vault: $VAULT_NAME"
    log_info "Serviço: $SERVICE_NAME"

    # Mapeamento de secrets específicos para Redis Infrastructure
    declare -gA secrets_mapping

    # Configurar mapeamento baseado no serviço
    case "$SERVICE_NAME" in
        "redis-infraestrutura"|"redis")
            # Secrets específicos para Redis Infrastructure
            secrets_mapping=(
                # Redis Secrets - PADRONIZADOS PARA UPPERCASE
                ["conexao-de-sorte-redis-password"]="REDIS_PASSWORD"
                ["conexao-de-sorte-redis-host"]="REDIS_HOST"
                ["conexao-de-sorte-redis-port"]="REDIS_PORT"
                ["conexao-de-sorte-redis-database"]="REDIS_DATABASE"

                # Database Secrets (para conexão com outros serviços)
                ["conexao-de-sorte-database-password"]="DATABASE_PASSWORD"
                ["conexao-de-sorte-database-username"]="DATABASE_USERNAME"
                ["conexao-de-sorte-database-host"]="DATABASE_HOST"
                ["conexao-de-sorte-database-port"]="DATABASE_PORT"

                # JWT Secrets (para validação de tokens)
                ["conexao-de-sorte-jwt-secret"]="JWT_SECRET"
                ["conexao-de-sorte-jwt-signing-key"]="JWT_SIGNING_KEY"
                ["conexao-de-sorte-jwt-verification-key"]="JWT_VERIFICATION_KEY"

                # Monitoring & Security
                ["conexao-de-sorte-monitoring-token"]="MONITORING_TOKEN"
                ["conexao-de-sorte-session-secret"]="SESSION_SECRET"
                ["conexao-de-sorte-encryption-master-key"]="ENCRYPTION_MASTER_KEY"
            )
            ;;
        *)
            # Mapeamento padrão para outros serviços
            secrets_mapping=(
                ["conexao-de-sorte-redis-password"]="REDIS_PASSWORD"
                ["conexao-de-sorte-redis-host"]="REDIS_HOST"
                ["conexao-de-sorte-redis-port"]="REDIS_PORT"
            )
            ;;
    esac

    local success_count=0
    local error_count=0
    local skip_count=0

    for keyvault_secret in "${!secrets_mapping[@]}"; do
        local docker_secret="${secrets_mapping[$keyvault_secret]}"

        log_step "Processando: $keyvault_secret -> $docker_secret"

        # Get secret from Key Vault
        local secret_value
        if secret_value=$(get_secret_from_keyvault "$keyvault_secret"); then
            if [[ -n "$secret_value" && "$secret_value" != "null" ]]; then
                # Create Docker Secret
                if create_docker_secret "$docker_secret" "$secret_value"; then
                    ((++success_count))
                else
                    ((++skip_count))
                fi
            else
                log_warning "Secret vazio no Key Vault: $keyvault_secret"
                ((++skip_count))
            fi
        else
            log_warning "Secret não encontrado no Key Vault: $keyvault_secret"
            ((++error_count))
        fi
    done

    # Summary
    echo ""
    log_info "=== RESUMO DA SINCRONIZAÇÃO ==="
    log_success "Secrets criados: $success_count"
    log_warning "Secrets pulados: $skip_count"
    log_error "Secrets com erro: $error_count"

    # Verificar se secrets críticos falharam
    local critical_failures=0
    local critical_secrets=("REDIS_PASSWORD")

    for critical in "${critical_secrets[@]}"; do
        if ! docker secret inspect "$critical" &> /dev/null; then
            log_error "Secret crítico ausente: $critical"
            ((++critical_failures))
        fi
    done

    if [[ $critical_failures -gt 0 ]]; then
        log_error "❌ Falha crítica: $critical_failures secrets essenciais não foram criados"
        log_error "📋 Verifique se os secrets existem no Azure Key Vault e tenha permissões adequadas"
        return 1
    fi

    if [[ $error_count -gt 0 ]]; then
        log_warning "⚠️ Alguns secrets falharam, mas secrets críticos estão disponíveis"
        return 0
    fi

    log_success "✅ Sincronização concluída com sucesso"
    return 0
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_secrets() {
    log_step "Validando secrets criados..."

    local required_secrets=("REDIS_PASSWORD")
    local missing_secrets=()

    for secret in "${required_secrets[@]}"; do
        if docker secret inspect "$secret" &> /dev/null; then
            log_success "✓ $secret"
        else
            log_error "✗ $secret (AUSENTE)"
            missing_secrets+=("$secret")
        fi
    done

    if [[ ${#missing_secrets[@]} -gt 0 ]]; then
        log_error "Secrets obrigatórios ausentes: ${missing_secrets[*]}"
        return 1
    fi

    log_success "Todos os secrets obrigatórios estão disponíveis"
    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "🔐 AZURE KEY VAULT TO DOCKER SECRETS SYNC SCRIPT - REDIS INFRASTRUCTURE"
    echo "============================================================================"
    echo "Vault: $VAULT_NAME"
    echo "Serviço: $SERVICE_NAME"
    echo "Timestamp: $(date)"
    echo ""

    # Run prerequisite checks
    if ! check_prerequisites; then
        log_error "Pré-requisitos não atendidos"
        exit 1
    fi

    # Sync secrets
    if ! sync_secrets; then
        log_error "Falha na sincronização de secrets"
        exit 1
    fi

    # Validate results
    if ! validate_secrets; then
        log_error "Validação de secrets falhou"
        exit 1
    fi

    log_success "🎉 Script executado com sucesso!"
    echo ""
    log_info "Para usar os secrets em docker-compose.yml:"
    log_info "  secrets:"
    log_info "    redis_password:"
    log_info "      external: true"
    log_info "      name: REDIS_PASSWORD"
    echo ""
    log_info "Para debug, execute:"
    log_info "  docker secret ls"
    echo ""
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi