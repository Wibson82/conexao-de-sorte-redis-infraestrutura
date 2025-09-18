#!/bin/bash

# ================================================================================
# 🔍 DOCKER SECRETS VALIDATION SCRIPT
# ================================================================================
# Este script valida se todos os Docker Secrets necessários estão criados
# e acessíveis para o projeto Conexão de Sorte
#
# Uso: ./validate-docker-secrets.sh [--verbose]
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

# Verificar se --verbose foi passado
VERBOSE_MODE=false
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE_MODE=true
fi

log_info "🔍 Iniciando validação de Docker Secrets"

# ================================================================================
# DEFINIR SECRETS NECESSÁRIOS
# ================================================================================

# Secrets essenciais (obrigatórios para funcionamento básico do Redis)
ESSENTIAL_SECRETS=(
    "REDIS_PASSWORD"
)

# Secrets completos do Redis Infrastructure
REDIS_SECRETS=(
    "REDIS_PASSWORD"
    "REDIS_HOST"
    "REDIS_PORT"
    "REDIS_DATABASE"
)

# ================================================================================
# FUNÇÕES AUXILIARES
# ================================================================================

# Função para verificar se secret existe
secret_exists() {
    local secret_name="$1"
    docker secret ls --format "{{.Name}}" | grep -q "^${secret_name}$"
}

# Função para obter informações do secret
get_secret_info() {
    local secret_name="$1"
    docker secret inspect "$secret_name" --format "{{.CreatedAt}}" 2>/dev/null || echo "N/A"
}

# Função para validar um grupo de secrets
validate_secret_group() {
    local -n secrets_array=$1
    local group_name="$2"
    local missing_secrets=()
    local existing_secrets=()

    log_info "📋 Validando grupo: $group_name"

    for secret in "${secrets_array[@]}"; do
        if secret_exists "$secret"; then
            existing_secrets+=("$secret")
            if [[ $VERBOSE_MODE == true ]]; then
                created_at=$(get_secret_info "$secret")
                log_success "  ✅ $secret (criado: $created_at)"
            fi
        else
            missing_secrets+=("$secret")
            if [[ $VERBOSE_MODE == true ]]; then
                log_error "  ❌ $secret (não encontrado)"
            fi
        fi
    done

    # Resumo do grupo
    if [[ ${#missing_secrets[@]} -eq 0 ]]; then
        log_success "✅ Grupo '$group_name': ${#existing_secrets[@]}/${#secrets_array[@]} secrets OK"
        return 0
    else
        log_error "❌ Grupo '$group_name': ${#missing_secrets[@]} secrets faltando: ${missing_secrets[*]}"
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

# ================================================================================
# VALIDAÇÃO DOS SECRETS
# ================================================================================

log_info "🚀 Iniciando validação de secrets..."

# Variáveis para controle de validação
essential_valid=true
redis_valid=true

# Validar secrets essenciais
log_info "🔑 Validando secrets essenciais..."
missing_essential=()

for secret in "${ESSENTIAL_SECRETS[@]}"; do
    if ! secret_exists "$secret"; then
        missing_essential+=("$secret")
        essential_valid=false
    fi
done

if [[ $essential_valid == true ]]; then
    log_success "✅ Todos os secrets essenciais estão presentes"
else
    log_error "❌ Secrets essenciais faltando: ${missing_essential[*]}"
fi

# Validar grupos de secrets
if ! validate_secret_group REDIS_SECRETS "Redis Infrastructure"; then
    redis_valid=false
fi

# ================================================================================
# VERIFICAÇÃO DE CONECTIVIDADE (se verbose)
# ================================================================================

if [[ $VERBOSE_MODE == true ]]; then
    log_info "🔗 Verificando conectividade com secrets..."

    # Tentar criar um container temporário para testar acesso aos secrets
    if secret_exists "REDIS_PASSWORD"; then
        log_info "🧪 Testando acesso ao REDIS_PASSWORD..."

        # Criar um container temporário que usa o secret
        if docker run --rm --detach \
            --name secret-test-redis \
            --secret source=REDIS_PASSWORD,target=/run/secrets/REDIS_PASSWORD \
            alpine:latest sleep 10 >/dev/null 2>&1; then

            # Verificar se o secret está acessível
            if docker exec secret-test-redis test -f /run/secrets/REDIS_PASSWORD >/dev/null 2>&1; then
                log_success "  ✅ REDIS_PASSWORD acessível via container"
            else
                log_error "  ❌ REDIS_PASSWORD não acessível via container"
            fi

            # Limpar container de teste
            docker stop secret-test-redis >/dev/null 2>&1 || true
        else
            log_warning "  ⚠️ Não foi possível testar acesso ao REDIS_PASSWORD"
        fi
    fi
fi

# ================================================================================
# ESTATÍSTICAS GERAIS
# ================================================================================

log_info "📊 Coletando estatísticas..."

# Contar todos os secrets do projeto
# Combinar todos os secrets para relatório
all_project_secrets=()
all_project_secrets+=("${REDIS_SECRETS[@]}")

# Remover duplicatas
IFS=" " read -r -a unique_secrets <<< "$(printf '%s\n' "${all_project_secrets[@]}" | sort -u | tr '\n' ' ')"

total_expected=${#unique_secrets[@]}
total_existing=0

for secret in "${unique_secrets[@]}"; do
    if secret_exists "$secret"; then
        ((total_existing++))
    fi
done

# ================================================================================
# RELATÓRIO FINAL
# ================================================================================

log_info "📊 RELATÓRIO DE VALIDAÇÃO"
echo "============================================================"
echo "🕒 Timestamp: $(date)"
echo "🔧 Modo Verbose: $VERBOSE_MODE"
echo ""
echo "📈 Estatísticas Gerais:"
echo "  📦 Total esperado: $total_expected secrets"
echo "  ✅ Total existente: $total_existing secrets"
echo "  📊 Cobertura: $((total_existing * 100 / total_expected))%"
echo ""

echo "📋 Status por Grupo:"
if [[ $essential_valid == true ]]; then
    echo "  🔑 Essenciais: ✅ OK"
else
    echo "  🔑 Essenciais: ❌ FALHA"
fi

if [[ $redis_valid == true ]]; then
    echo "  🔴 Redis: ✅ OK"
else
    echo "  🔴 Redis: ❌ FALHA"
fi

echo ""

# Determinar status final
if [[ $essential_valid == true ]]; then
    if [[ $redis_valid == true ]]; then
        log_success "🎉 Validação concluída: TODOS OS SECRETS DO REDIS VÁLIDOS!"
        exit 0
    else
        log_warning "⚠️ Validação concluída: SECRETS ESSENCIAIS OK, mas alguns opcionais faltando"
        exit 0
    fi
else
    log_error "💥 Validação falhou: SECRETS ESSENCIAIS DO REDIS FALTANDO!"
    exit 1
fi