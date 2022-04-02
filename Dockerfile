# Copyright (c) 2021 Tailscale Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# from https://github.com/tailscale/tailscale/blob/main/docs/k8s/Dockerfile

FROM ghcr.io/tailscale/tailscale:latest
COPY run.sh /run.sh
CMD "/run.sh"
