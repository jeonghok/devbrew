#!/usr/bin/env bash
# gh-identity.sh — resolve the authenticated GitHub identity (login + immutable
# numeric id) for consent display + comment-upsert --my-id. Encapsulates
# `gh api user` so the orchestrator SKILL never writes raw `gh api` (design §4
# invariant). FAIL-CLOSED: gh absent/unauth/error → empty id (caller must not publish).
set -uo pipefail
login=""; id=""
if command -v gh >/dev/null 2>&1; then
  line="$(gh api user --jq '[.login, (.id|tostring)]|@tsv' 2>/dev/null)" || line=""
  IFS=$'\t' read -r login id <<<"$line"
fi
echo "login: $login"
echo "id: $id"
