# LlamaStack Playground K8s MCP Deployment Guide

## Overview
This deployment guide helps you deploy the LlamaStack Playground with Model Context Protocol (MCP) on a Kubernetes cluster using CPU-friendly models instead of GPU-dependent ones.

## Changes Made for CPU Deployment

### Model Configuration Changes
- **Replaced**: `llama-4-scout-17b-16e-w4a16` (17B parameters, requires API token)
- **With**: `qwen2-1.5b-instruct` (1.5B parameters, CPU-friendly)

### Key Modifications
1. **vLLM Model**: Changed from `qwen3-8b` to `qwen2-1.5b-instruct`
2. **Resource Limits**: Added CPU/memory constraints instead of GPU requirements
3. **API Dependencies**: Removed external API token requirements
4. **Service URLs**: Updated to use local cluster services

## Prerequisites

1. **Kubernetes Cluster**: Working cluster with kubectl access
2. **Kustomize**: For building and applying manifests
3. **Helm**: For installing chart dependencies
4. **Namespace Access**: Ability to create namespaces

## Deployment Steps

### 1. Clone and Navigate to Directory
```bash
git clone <repository-url>
cd ai-accelerator-examples/examples/llamastack-playground-k8s-mcp
```

### 2. Deploy Namespaces
```bash
kubectl apply -k namespaces/overlays/default/
```

This creates three namespaces:
- `ai-agent-lls` - LlamaStack services
- `ai-agent-mcp` - Model Context Protocol services  
- `ai-agent-vllm` - vLLM inference services

### 3. Deploy vLLM Service
```bash
kubectl apply -k vllm/overlays/default/
```

This deploys the `qwen2-1.5b-instruct` model with CPU-only configuration.

### 4. Deploy Kubernetes MCP
```bash
kubectl apply -k kubernetes-mcp/overlays/default/
```

This deploys the Model Context Protocol service for Kubernetes integration.

### 5. Deploy LlamaStack Distribution
```bash
kubectl apply -k llamastack/overlays/default/
```

This deploys the main LlamaStack service configured to use the local vLLM endpoint.

### 6. Deploy LlamaStack Playground
```bash
kubectl apply -k llamastack-playground/overlays/default/
```

This deploys the web interface for interacting with the models.

## Verification

### Check Pod Status
```bash
# Check all pods across namespaces
kubectl get pods -n ai-agent-lls
kubectl get pods -n ai-agent-mcp
kubectl get pods -n ai-agent-vllm
```

### Check Services
```bash
kubectl get svc -n ai-agent-lls
kubectl get svc -n ai-agent-mcp
kubectl get svc -n ai-agent-vllm
```

### Access the Playground
1. **Port Forward** (for testing):
   ```bash
   kubectl port-forward -n ai-agent-lls svc/llamastack-playground 8080:80
   ```
   Then access: http://localhost:8080

2. **Ingress/Route** (for production):
   Configure your cluster's ingress controller to expose the service.

## Model Specifications

### Qwen2-1.5B-Instruct
- **Size**: 1.5 billion parameters
- **Memory**: ~3GB model + ~4GB runtime = ~8GB total
- **CPU**: 2-4 cores recommended
- **Use Case**: Instruction following, chat, code assistance
- **Languages**: Multilingual (strong English and Chinese)

## Troubleshooting

### Common Issues

1. **Pod Pending State**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```
   Check for resource constraints or node affinity issues.

2. **Model Loading Issues**
   ```bash
   kubectl logs <vllm-pod-name> -n ai-agent-vllm
   ```
   Check if the model download is successful.

3. **Service Connection Issues**
   ```bash
   kubectl get endpoints -n ai-agent-lls
   kubectl get endpoints -n ai-agent-vllm
   ```
   Verify service discovery is working.

### Resource Requirements

**Minimum Cluster Resources:**
- **CPU**: 6 cores total (2 for vLLM, 1 for LlamaStack, 1 for MCP, 1 for Playground, 1 buffer)
- **Memory**: 12GB total (8GB for vLLM, 2GB for other services, 2GB buffer)
- **Storage**: 10GB for model artifacts

### Performance Tuning

1. **CPU Optimization**:
   - Adjust `resources.requests.cpu` in vLLM values.yaml
   - Consider CPU affinity for better performance

2. **Memory Optimization**:
   - Monitor actual memory usage and adjust limits
   - Consider memory-mapped model loading

3. **Concurrency**:
   - Adjust vLLM worker processes based on CPU cores
   - Configure appropriate request batching

## Alternative Models

If `qwen2-1.5b-instruct` doesn't meet your needs, consider these alternatives:

### Smaller Models (< 1GB memory)
- `microsoft/DialoGPT-small` - 117M parameters
- `distilgpt2` - 82M parameters  
- `gpt2` - 124M parameters

### Medium Models (1-4GB memory)
- `microsoft/DialoGPT-medium` - 345M parameters
- `EleutherAI/gpt-neo-125M` - 125M parameters
- `facebook/opt-350m` - 350M parameters

To use an alternative model, update the `model.uri` in `vllm/base/values.yaml` and corresponding references in the LlamaStack configuration.

## Security Considerations

1. **Network Policies**: Implement network policies to restrict inter-namespace communication
2. **RBAC**: Configure appropriate role-based access controls
3. **Resource Quotas**: Set namespace resource quotas to prevent resource exhaustion
4. **Pod Security**: Use pod security standards to enforce security policies

## Cleanup

To remove the deployment:
```bash
kubectl delete -k llamastack-playground/overlays/default/
kubectl delete -k llamastack/overlays/default/
kubectl delete -k kubernetes-mcp/overlays/default/
kubectl delete -k vllm/overlays/default/
kubectl delete -k namespaces/overlays/default/
```
