#!/usr/bin/env bats

@test "require_command succeeds when command exists" {
  run bash -c 'source scripts/functions.sh; require_command bash'

  [ "$status" -eq 0 ]
}

@test "require_command fails when command is missing" {
  run bash -c 'source scripts/functions.sh; require_command definitely_missing_command_123'

  [ "$status" -eq 1 ]
  [[ "$output" == *"required command 'definitely_missing_command_123' is not installed"* ]]
}

@test "ask_yes_no accepts default yes on empty input" {
  run bash -c "source scripts/functions.sh; ask_yes_no 'Proceed?' 'Y' <<< ''"

  [ "$status" -eq 0 ]
}

@test "ask_yes_no accepts default no on empty input" {
  run bash -c "source scripts/functions.sh; ask_yes_no 'Proceed?' 'N' <<< ''"

  [ "$status" -eq 1 ]
}

@test "prompt_value sets variable when empty" {
  run bash -c "source scripts/functions.sh; V=''; prompt_value V 'Value' <<< 'hello'; echo \"\$V\""

  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]
}

@test "prompt_value keeps existing variable value" {
  run bash -c "source scripts/functions.sh; V='existing'; prompt_value V 'Value'; echo \"\$V\""

  [ "$status" -eq 0 ]
  [[ "$output" == "existing" ]]
}
