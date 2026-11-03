#!/usr/bin/env bash
set -eu

KYVERNO_VERSION="v1.13.2"
case "$(uname -m)" in
  x86_64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture $(uname -m)"; exit 1 ;;
esac

echo "Installing the Kyverno CLI ${KYVERNO_VERSION}..."
curl -sSL -o /tmp/kyverno-cli.tar.gz "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/kyverno-cli_${KYVERNO_VERSION}_linux_${ARCH}.tar.gz"
tar -xzf /tmp/kyverno-cli.tar.gz -C /usr/local/bin kyverno
chmod +x /usr/local/bin/kyverno
kyverno version
