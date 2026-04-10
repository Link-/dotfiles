#!/bin/bash

SSH_KEY="$HOME/.ssh/id_github_work_codespaces"

if [ ! -f "$SSH_KEY" ]; then
  echo "Error: SSH key not found at $SSH_KEY" >&2
  exit 1
fi

if [ ! -r "$SSH_KEY" ]; then
  echo "Error: SSH key at $SSH_KEY is not readable" >&2
  exit 1
fi

eval "$(ssh-agent -s)" || {
  echo "Error: Failed to start ssh-agent" >&2
  exit 1
}

ssh-add "$SSH_KEY" || {
  echo "Error: Failed to add SSH key to agent" >&2
  kill "$SSH_AGENT_PID" 2>/dev/null
  exit 1
}

echo "SSH key added successfully. Agent PID: $SSH_AGENT_PID"
