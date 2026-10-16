#!/usr/bin/env bash
# ============================================================================
# AI SCAN TEST FIXTURE — DO NOT MERGE
# Purpose: evaluate GitHub "AI Scan for pull requests" (Content Lab dossier
#          2026-10-16-ai-scan-for-pull-requests-generally-available).
# This file contains INTENTIONAL vulnerabilities for scanner evaluation only.
# It lives on a short-lived test branch and will be deleted after the test.
# Expected AI Scan finding category: "String injection"
#   (unsafe string-built shell with missing/incorrect escaping or sanitization)
# ============================================================================
set -euo pipefail

# INTENTIONAL VULNERABILITY (CWE-78 OS Command Injection — test only):
# unsanitized positional parameter interpolated into eval.
restart_service() {
  local service_name="$1"
  eval "systemctl restart ${service_name}"
}

# INTENTIONAL VULNERABILITY (CWE-78 OS Command Injection — test only):
# user-controlled input concatenated into a shell command string, then
# executed via unquoted variable expansion.
fetch_config() {
  local host="$1"
  local path="$2"
  cmd="curl -fsSL http://${host}/${path} -o /tmp/svc.conf"
  $cmd
}

restart_service "${1:-}"
fetch_config "${2:-}" "${3:-}"
