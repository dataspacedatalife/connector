#!/usr/bin/env bash

assert_file_exists() {
  local file_path="$1"
  [[ -f "$file_path" ]] || {
    echo "Expected file to exist: $file_path"
    return 1
  }
}

assert_file_contains() {
  local file_path="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file_path" || {
    echo "Expected '$file_path' to contain: $expected"
    return 1
  }
}

assert_file_not_contains() {
  local file_path="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file_path"; then
    echo "Expected '$file_path' to not contain: $unexpected"
    return 1
  fi
}
