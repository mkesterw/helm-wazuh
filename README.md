# Wazuh Helm Chart para Kubernetes com Rancher

Helm Chart completo para implantação do Wazuh Security Platform no Kubernetes com suporte a **multi-tenant** (um Wazuh por cliente em seu próprio namespace).

## Arquitetura

```
                    ┌─────────────────────────────────────────┐
                    │            Namespace: cliente1           │
                    │                                          │
  Agentes ──1514──► │  Manager Worker (x2)                    │
  Agentes ──1515──► │  Manager Master (x1) ──55000──► API     │
                    │         │                                │
                    │         ▼                                │
                    │  Wazuh Indexer (x3)  ◄── Dashboard      │
                    │   (OpenSearch)         (HTTPS :443)      │
                    └─────────────────────────────────────────┘
```

### Componentes

| Componente | Imagem | Porta | Função |
|---|---|---|---|
| Manager Master | `wazuh/wazuh-manager:5.0.0` | 1515, 1516, 55000 | Gerência, registro de agentes, API |
| Manager Worker | `wazuh/wazuh-manager:5.0.0` | 1514, 1516 | Recebimento de eventos dos agentes |
| Wazuh Indexer | `wazuh/wazuh-indexer:5.0.0` | 9200, 9300 | Armazenamento e busca (OpenSearch) |
| Wazuh Dashboard | `wazuh/wazuh-dashboard:5.0.0` | 443 | Interface web |

## Pré-requisitos

- Kubernetes 1.24+
- Helm 3.10+
- Rancher (RKE2/K3s) ou outro cluster Kubernetes
- StorageClass disponível (padrão: `rancher.io/local-path`)
- Para acesso externo dos agentes: LoadBalancer (MetalLB, cloud LB) ou Traefik

## Instalação Rápida (Desenvolvimento)

```bash
# Instalar em modo minimal para testes
helm install wazuh ./helm/wazuh \
  -n wazuh-dev --create-namespace \
  -f helm/wazuh/values-minimal.yaml

# Acompanhar a inicialização
kubectl get pods -n wazuh-dev -w
```

## Multi-Tenant - Um Cliente por Namespace

Cada cliente recebe seu próprio namespace com stack Wazuh isolada:

```bash
# Cliente 1
helm install wazuh ./helm/wazuh \
  -n cliente1 --create-namespace \
  -f helm/wazuh/values-production.yaml \
  --set ingress.dashboard.host=wazuh-cliente1.seudominio.com \
  --set secrets.indexer.password='SenhaForteCliente1!' \
  --set secrets.wazuhApi.password='ApiSenhaCliente1!' \
  --set secrets.authdPass='AuthdCliente1!' \
  --set secrets.clusterKey='Chave32CharsParaCliente1Aqui12'

# Cliente 2
helm install wazuh ./helm/wazuh \
  -n cliente2 --create-namespace \
  -f helm/wazuh/values-production.yaml \
  --set ingress.dashboard.host=wazuh-cliente2.seudominio.com \
  --set secrets.indexer.password='SenhaForteCliente2!' \
  --set secrets.wazuhApi.password='ApiSenhaCliente2!' \
  --set secrets.authdPass='AuthdCliente2!' \
  --set secrets.clusterKey='Chave32CharsParaCliente2Aqui12'
```

## Certificados TLS

### Geração Automática (Padrão)

Por padrão, um Job Kubernetes gera os certificados automaticamente no primeiro install:

```yaml
# values.yaml
certs:
  generate: true  # Um Job pre-install gera e armazena os certs em Secrets
```

> **Nota:** Requer acesso à internet para `apk add openssl`. Para ambientes air-gapped, use a opção abaixo.

### Certificados Existentes (Air-gapped / Produção)

Para ambientes sem acesso à internet ou quando você já tem certificados:

```yaml
certs:
  generate: false
  existingSecrets:
    # Secret com: root-ca.pem, indexer.pem, indexer-key.pem,
    #             admin.pem, admin-key.pem, server.pem, server-key.pem
    indexerCerts: "meu-indexer-certs"
    # Secret com: root-ca.pem, dashboard.pem, dashboard-key.pem
    dashboardCerts: "meu-dashboard-certs"
```

## StorageClass para Rancher

### Local-Path (Padrão RKE2/K3s - Desenvolvimento)
```yaml
storageClass:
  create: true
  name: wazuh-storage
  provisioner: "rancher.io/local-path"
```

### Longhorn (Recomendado para Produção com Rancher)
```yaml
storageClass:
  create: false
  name: longhorn
```

### EKS
```yaml
storageClass:
  create: true
  name: wazuh-storage
  provisioner: kubernetes.io/aws-ebs
  parameters:
    type: gp3
    encrypted: "true"
```

## Acesso Externo para Agentes

### Opção 1: LoadBalancer (Simples)
```yaml
service:
  events:
    type: LoadBalancer  # Porta 1514 com IP externo
  registration:
    type: LoadBalancer  # Porta 1515 com IP externo
```

### Opção 2: Traefik IngressRouteTCP

Primeiro, configure o Traefik com entrypoints customizados:
```yaml
# values do helm chart do Traefik
ports:
  wazuh-1514:
    port: 1514
    expose: true
    exposedPort: 1514
    protocol: TCP
  wazuh-1515:
    port: 1515
    expose: true
    exposedPort: 1515
    protocol: TCP
```

Depois, no Wazuh:
```yaml
ingress:
  enabled: true
  traefik:
    enabled: true
    entrypoints:
      events: "wazuh-1514"
      registration: "wazuh-1515"
      dashboard: "websecure"
```

### Opção 3: NodePort
```yaml
service:
  events:
    type: NodePort
  registration:
    type: NodePort
```

## Acesso ao Dashboard

### Via NGINX Ingress (Rancher)
```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  dashboard:
    host: "wazuh.seudominio.com"
```

### Via Port-Forward (Desenvolvimento)
```bash
kubectl port-forward svc/wazuh-dashboard 8443:443 -n <namespace>
# Acesse: https://localhost:8443
```

## Configuração de Network Policies

Para ambientes com segmentação de rede:
```yaml
networkPolicy:
  enabled: true
```

Isso cria políticas que implementam o princípio de menor privilégio entre os componentes.

## Registrar Agentes Wazuh

Após obter o IP externo do serviço de registro:

```bash
# Obter IP externo
kubectl get svc wazuh-registration -n <namespace>

# No servidor do agente (Linux)
WAZUH_MANAGER="<IP-EXTERNO>" \
WAZUH_REGISTRATION_SERVER="<IP-EXTERNO>" \
WAZUH_REGISTRATION_PASSWORD="<authdPass>" \
  bash -c "$(curl -s https://packages.wazuh.com/4.x/apt/agent-install.sh)"
```

## Comandos Úteis

```bash
# Status geral
kubectl get pods,svc,pvc -n <namespace>

# Logs do Manager Master
kubectl logs -f statefulset/wazuh-manager-master -n <namespace>

# Logs do Indexer
kubectl logs -f statefulset/wazuh-indexer -n <namespace>

# Acessar API do Wazuh
kubectl port-forward svc/wazuh-api 55000:55000 -n <namespace>
curl -k -u wazuh-wui:<senha> https://localhost:55000

# Ver certificados gerados
kubectl get secrets -n <namespace> | grep certs

# Upgrade do chart
helm upgrade wazuh ./helm/wazuh -n <namespace> -f values-production.yaml

# Desinstalar (Secrets de certs são mantidos por segurança)
helm uninstall wazuh -n <namespace>

# Remover Secrets de certs manualmente (se quiser limpar tudo)
kubectl delete secret -l app.kubernetes.io/instance=wazuh -n <namespace>
```

## Estrutura do Helm Chart

```
helm/wazuh/
├── Chart.yaml                          # Metadados do chart
├── values.yaml                         # Valores padrão (leia e customize!)
├── values-minimal.yaml                 # Para desenvolvimento/testes
├── values-production.yaml              # Para produção
└── templates/
    ├── _helpers.tpl                    # Funções de template reutilizáveis
    ├── NOTES.txt                       # Mensagem pós-instalação
    ├── namespace.yaml                  # Namespace (opcional)
    ├── storageclass.yaml               # StorageClass
    ├── serviceaccount.yaml             # ServiceAccounts
    ├── rbac.yaml                       # RBAC para Job de certs
    ├── secrets.yaml                    # Secrets de credenciais
    ├── cert-gen-job.yaml               # Job gerador de certificados TLS
    ├── indexer-statefulset.yaml        # Wazuh Indexer (OpenSearch)
    ├── indexer-service.yaml            # Services do Indexer
    ├── dashboard-deployment.yaml       # Wazuh Dashboard
    ├── dashboard-service.yaml          # Service do Dashboard
    ├── manager-master-statefulset.yaml # Manager Master
    ├── manager-worker-statefulset.yaml # Manager Workers
    ├── manager-services.yaml           # Services do Manager
    ├── ingress.yaml                    # Ingress (NGINX ou Traefik)
    └── network-policies.yaml           # Network Policies
```

## Troubleshooting

### Pods do Indexer em CrashLoopBackOff
```bash
# Verificar vm.max_map_count (deve ser 262144)
kubectl describe pod <indexer-pod> -n <namespace>
# O init container "sysctl" tenta ajustar automaticamente
# Se falhar, configure no nó: sudo sysctl -w vm.max_map_count=262144
```

### Job de Certificados Falhou
```bash
kubectl logs job/wazuh-cert-gen -n <namespace>
# Se for falta de internet: use certs.generate: false e forneça os secrets
```

### Dashboard não Conecta ao Indexer
```bash
# Verificar se os certificados foram gerados corretamente
kubectl describe secret wazuh-indexer-certs -n <namespace>
# Verificar conectividade
kubectl exec -it <dashboard-pod> -n <namespace> -- curl -k https://wazuh-indexer:9200
```

### Verificar Status do Cluster Wazuh
```bash
kubectl exec -it <master-pod> -n <namespace> -- /var/ossec/bin/cluster_control -l
```
#   h e l m - w a z u h  
 