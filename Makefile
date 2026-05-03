.PHONY: help bootstrap teardown port-forward lint password apps

help:
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-15s %s\n", $$1, $$2}'

bootstrap:  ## Bootstrap a fresh cluster (installs Argo CD + applies root app)
	./scripts/bootstrap.sh

teardown:  ## Tear down everything Argo CD manages
	./scripts/teardown.sh

port-forward:  ## Port-forward Argo CD UI to localhost:8081
	./scripts/port-forward-argocd.sh

lint:  ## Lint all YAML
	./scripts/lint.sh

password:  ## Print the Argo CD initial admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath='{.data.password}' | base64 -d && echo

apps:  ## List Argo CD Applications and their state
	@kubectl get applications -n argocd

sync:  ## Force-sync all Argo CD Applications (rare; usually selfHeal handles it)
	@for app in $$(kubectl -n argocd get applications -o name); do \
	  kubectl -n argocd patch $$app --type merge -p '{"operation":{"sync":{}}}' 2>/dev/null || true; \
	done

kind-up:  ## Create local kind cluster + bootstrap (LEAN=1 for single node)
	./scripts/kind-up.sh

kind-down:  ## Delete local kind cluster (releases all memory)
	./scripts/kind-down.sh
