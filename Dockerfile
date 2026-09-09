# Reproducible environment for the silent-green eval.
#
# The point of running in a container is control. No home-directory settings,
# no MCP servers, no memory, no local model default. Both arms differ by one
# file and nothing else.
#
#   docker build -t silent-green-eval .
#   docker run --rm \
#     -e ANTHROPIC_API_KEY=sk-... \
#     -e N=5 \
#     -v "$PWD/eval/results:/home/runner/repo/eval/results" \
#     silent-green-eval
#
# Results land in ./eval/results on the host.

FROM golang:1.22-bookworm

# Node is only here to run the coding agent, not to build anything.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git make gnupg \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Claude Code refuses to skip permission prompts as root, and we need
# non-interactive tool use, so the eval runs unprivileged.
RUN useradd -ms /bin/bash runner
USER runner
ENV HOME=/home/runner
ENV NPM_CONFIG_PREFIX=/home/runner/.npm-global
ENV PATH=/home/runner/.npm-global/bin:$PATH

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /home/runner/repo
COPY --chown=runner:runner . .

# git needs an identity for the local clones the harness makes.
RUN git config --global user.email "eval@example.com" \
 && git config --global user.name "eval runner" \
 && git config --global init.defaultBranch main \
 && git config --global --add safe.directory /home/runner/repo

# Pin the model so a result is interpretable six months from now.
ENV MODEL=claude-sonnet-4-6
ENV N=5

ENTRYPOINT ["./eval/run-eval.sh"]
