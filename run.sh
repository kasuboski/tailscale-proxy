#! /bin/sh
# Copyright (c) 2021 Tailscale Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# from https://raw.githubusercontent.com/tailscale/tailscale/main/docs/k8s/run.sh

export PATH="$PATH:/tailscale/bin"

AUTH_KEY="${AUTH_KEY:-}"
ROUTES="${ROUTES:-}"
DEST_IP="${DEST_IP:-}"
DEST_PORT="${DEST_PORT:-}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
USERSPACE="${USERSPACE:-true}"
KUBE_SECRET="${KUBE_SECRET:-tailscale}"
HOSTNAME="${HOSTNAME:-}"

set -e

TAILSCALED_ARGS="--state=kube:${KUBE_SECRET} --socket=/tmp/tailscaled.sock"

if [[ "${USERSPACE}" == "true" ]]; then
  if [[ ! -z "${DEST_IP}" ]] || [[ ! -z "${DEST_PORT}" ]]; then
    echo "IP forwarding is not supported in userspace mode"
    exit 1
  fi
  TAILSCALED_ARGS="${TAILSCALED_ARGS} --tun=userspace-networking"
else
  if [[ ! -d /dev/net ]]; then
    mkdir -p /dev/net
  fi

  if [[ ! -c /dev/net/tun ]]; then
    mknod /dev/net/tun c 10 200
  fi
fi

echo "Starting tailscaled"
tailscaled ${TAILSCALED_ARGS} &
PID=$!

UP_ARGS="--accept-dns=false"
if [[ ! -z "${ROUTES}" ]]; then
  UP_ARGS="--advertise-routes=${ROUTES} ${UP_ARGS}"
fi
if [[ ! -z "${AUTH_KEY}" ]]; then
  UP_ARGS="--authkey=${AUTH_KEY} ${UP_ARGS}"
fi
if [[ ! -z "${HOSTNAME}" ]]; then
  UP_ARGS="--hostname=${HOSTNAME} ${UP_ARGS}"
fi
if [[ ! -z "${EXTRA_ARGS}" ]]; then
  UP_ARGS="${UP_ARGS} ${EXTRA_ARGS:-}"
fi

echo "Running tailscale up"
tailscale --socket=/tmp/tailscaled.sock up ${UP_ARGS}

if [[ ! -z "${DEST_IP}" ]]; then
  echo "Adding iptables rule for DNAT"
  iptables -t nat -I PREROUTING -d "$(tailscale --socket=/tmp/tailscaled.sock ip -4)" -j DNAT --to-destination "${DEST_IP}"
fi

if [[ ! -z "${DEST_PORT}" ]]; then
  echo "Adding iptables rules for REDIRECT"
  iptables -t nat -I PREROUTING -p tcp -d "$(tailscale --socket=/tmp/tailscaled.sock ip -4)" --dport 1:65535 -j REDIRECT --to-ports "${DEST_PORT}"
fi

wait ${PID}

