set -euo pipefail

err() {
    local exitcode=$1
    shift
    echo "ERROR: $@" >&2
    exit $exitcode
}

warn() {
    echo "WARN : $@" >&2
}

info() {
    if [[ -n "$VERBOSE" ]]; then
	echo "INFO : $@" >&2
    fi
}

prompt_value() {
  local var_name="$1"
  local prompt_text="$2"
  local is_secret="${3:-false}"
  local current="${!var_name:-}"

  if [[ -n "$current" ]]; then
    return
  fi

  if [[ "$is_secret" == "true" ]]; then
    local value=""
    while [[ -z "$value" ]]; do
      read -r -s -p "$prompt_text: " value
      echo
    done
    printf -v "$var_name" '%s' "$value"
  else
    local value=""
    while [[ -z "$value" ]]; do
      read -r -p "$prompt_text: " value
    done
    printf -v "$var_name" '%s' "$value"
  fi
}

ask_yes_no() {
  local prompt="$1"
  local default_answer="${2:-N}"
  local reply=""

  while true; do
    if [[ "$default_answer" == "Y" ]]; then
      read -r -p "$prompt [Y/n]: " reply
      reply="${reply:-Y}"
    else
      read -r -p "$prompt [y/N]: " reply
      reply="${reply:-N}"
    fi

    case "$reply" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command '$1' is not installed or not in PATH." >&2
    exit 1
  }
}
