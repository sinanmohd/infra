# infra

everything i run, as code. if it's not in here, it doesn't exist.
secrets are encrypted using sops in repo. no, the keys are not in here.

## layout

- nix/os:     nixos hosts and modules
- nix/home:   home-manager, same idea
- nix/global: stuff shared between os and home
- charts:     helm charts for the k8s cluster
- appsets:    argocd applicationsets, applied by argocd.yaml
- tofu:       opentofu modules

## hosts

- kay: server. dns, k8s, observability, the usual suspects
- cez: laptop. secure boot via lanzaboote, disko, nixos-facter

## usage

deploy to a local machine

    nixos-rebuild switch --flake .#cez

deploy to a remote server

    deploy .#kay

bootstrap the k8s cluster, argocd takes it from here

    kubectl apply -f argocd.yaml
