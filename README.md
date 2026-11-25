# infra

everything i run, as code. if it's not in here, it doesn't exist.
secrets are encrypted using sops in repo. no, the keys are not in here.

## layout

- apps:       argocd root application, syncs appsets
- appsets:    argocd applicationsets, applied by apps/bootstrap.yaml
- charts:     helm charts for the k8s cluster
- nix/global: stuff shared between os and home
- nix/home:   home-manager, hosts and modules
- nix/os:     nixos, same idea
- tofu:       opentofu modules
- values:     per chart values and sops secrets

## usage

deploy to a local machine

    nixos-rebuild switch --flake .#cez

deploy to a remote server

    deploy .#kay

bootstrap the k8s cluster, argocd takes it from here

    kubectl apply -f apps/bootstrap.yaml
