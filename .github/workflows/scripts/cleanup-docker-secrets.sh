#!/bin/bash

# ================================================================================
# 🧹 DOCKER SECRETS CLEANUP SCRIPT
# ================================================================================
# Este script remove todos os Docker Secrets relacionados ao projeto Conexão de Sorte
# de forma segura, verificando se não estão em uso antes de removê-los
#
# Uso: ./cleanup-docker-secrets.sh [--force]
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

# Verificar se --force foi passado
FORCE_MODE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE_MODE=true
    log_warning "Modo --force ativado: secrets serão removidos mesmo se em uso"
fi

log_info "🧹 Iniciando limpeza de Docker Secrets do projeto Conexão de Sorte"

# ================================================================================
# DEFINIR SECRETS A SEREM REMOVIDOS
# ================================================================================

# Lista de secrets relacionados ao Redis Infrastructure
PROJECT_SECRETS=(
    # Redis Infrastructure
    "REDIS_PASSWORD"
    "REDIS_HOST"
    "REDIS_PORT"
    "REDIS_DATABASE"

    # Legacy Redis secrets (se existirem)
    "REDIS_ROOT_PASSWORD"
    "CONEXAO_REDIS_PASSWORD"
    "PROXYSQL_PASSWORD"
)

# ================================================================================
# FUNÇÕES AUXILIARES
# ================================================================================

# Função para verificar se secret está em uso
is_secret_in_use() {
    local secret_name="$1"

    # Verificar se algum serviço está usando o secret
    if docker service ls --format "{{.Name}}" | xargs -I {} docker service inspect {} 2>/dev/null | \
       jq -r '.[].Spec.TaskTemplate.ContainerSpec.Secrets[]?.SecretName // empty' 2>/dev/null | \
       grep -q "^${secret_name}$"; then
        return 0  # Em uso
    else
        return 1  # Não está em uso
    fi
}

# Função para remover secret com verificação
remove_secret_safe() {
    local secret_name="$1"

    # Verificar se secret existe
    if ! docker secret ls --format "{{.Name}}" | grep -q "^${secret_name}$"; then
        log_info "Secret '$secret_name' não existe - pulando"
        return 0
    fi

    # Verificar se está em uso (a menos que force mode esteja ativo)
    if [[ $FORCE_MODE == false ]] && is_secret_in_use "$secret_name"; then
        log_warning "Secret '$secret_name' está em uso - pulando (use --force para remover)"
        return 0
    fi

    # Tentar remover
    if docker secret rm "$secret_name" >/dev/null 2>&1; then
        log_success "Secret '$secret_name' removido com sucesso"
        return 0
    else
        log_error "Falha ao remover secret '$secret_name'"
        return 1
    fi
}

# ================================================================================
# VERIFICAÇÃO INICIAL
# ================================================================================

log_info "🔍 Verificando Docker Swarm..."

# Verificar se Docker Swarm está ativo
if ! docker info | grep -q "Swarm: active"; then
    log_error "Docker Swarm não está ativo - secrets só funcionam em modo Swarm"
    exit 1
fi

log_success "Docker Swarm está ativo"

# Listar secrets existentes relacionados ao projeto
log_info "📋 Secrets existentes relacionados ao projeto:"
existing_secrets=()

for secret in "${PROJECT_SECRETS[@]}"; do
    if docker secret ls --format "{{.Name}}" | grep -q "^${secret}$"; then
        existing_secrets+=("$secret")

        # Verificar se está em uso
        if is_secret_in_use "$secret"; then
            echo "  🔒 $secret (EM USO)"
        else
            echo "  📝 $secret (livre)"
        fi
    fi
done

if [[ ${#existing_secrets[@]} -eq 0 ]]; then
    log_info "Nenhum secret relacionado ao projeto encontrado"
    exit 0
fi

# ================================================================================
# CONFIRMAÇÃO (se não for force mode)
# ================================================================================

if [[ $FORCE_MODE == false ]]; then
    echo ""
    log_warning "Esta operação irá remover ${#existing_secrets[@]} secret(s)"
    log_warning "Secrets em uso serão pulados automaticamente"
    echo ""
    read -p "Deseja continuar? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operação cancelada pelo usuário"
        exit 0
    fi
fi

# ================================================================================
# PROCESSO DE LIMPEZA
# ================================================================================

log_info "🚀 Iniciando processo de limpeza..."

removed_count=0
skipped_count=0
failed_count=0

for secret in "${existing_secrets[@]}"; do
    if remove_secret_safe "$secret"; then
        # Verificar se foi realmente removido
        if ! docker secret ls --format "{{.Name}}" | grep -q "^${secret}$"; then
            ((removed_count++))
        else
            ((skipped_count++))
        fi
    else
        ((failed_count++))
    fi
done

# ================================================================================
# VERIFICAÇÃO FINAL
# ================================================================================

log_info "🔍 Verificação final..."

# Listar secrets restantes
remaining_secrets=()
for secret in "${PROJECT_SECRETS[@]}"; do
    if docker secret ls --format "{{.Name}}" | grep -q "^${secret}$"; then
        remaining_secrets+=("$secret")
    fi
done

# ================================================================================
# RELATÓRIO FINAL
# ================================================================================

log_info "📊 RELATÓRIO DE LIMPEZA"
echo "============================================================"
echo "🕒 Timestamp: $(date)"
echo "🔧 Modo Force: $FORCE_MODE"
echo ""
echo "📈 Estatísticas:"
echo "  ✅ Removidos: $removed_count"
echo "  ⏭️  Pulados: $skipped_count"
echo "  ❌ Falhas: $failed_count"
echo ""

if [[ ${#remaining_secrets[@]} -gt 0 ]]; then
    log_warning "Secrets restantes (${#remaining_secrets[@]}):"
    for secret in "${remaining_secrets[@]}"; do
        if is_secret_in_use "$secret"; then
            echo "  🔒 $secret (em uso)"
        else
            echo "  📝 $secret (motivo desconhecido)"
        fi
    done
else
    log_success "✨ Todos os secrets do projeto foram removidos!"
fi

echo ""

if [[ $failed_count -gt 0 ]]; then
    log_error "💥 Limpeza concluída com falhas!"
    exit 1
else
    log_success "🎉 Limpeza concluída com sucesso!"
    exit 0
fi