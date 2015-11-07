#!/bin/bash

set -e

[[ "$MANAGER_ONLY" = "MANAGER" ]] || { printf "Invalid value: '%s'. Expected 'MANAGER'.\n" "$MANAGER_ONLY" >/failed; exit 1; }
[[ "$HIDES_CONFIG" = "NSPAWN" ]] || { printf "Invalid value: '%s'. Expected 'NSPAWN'.\n" "$HIDES_CONFIG" >/failed; exit 1; }
[[ "$HIDES_CMDLINE" = "NSPAWN" ]] || { printf "Invalid value: '%s'. Expected 'NSPAWN'.\n" "$HIDES_CMDLINE" >/failed; exit 1; }
[[ "$B" = "ENVIRONMENT" ]] || { printf "Invalid value: '%s'. Expected 'ENVIRONMENT'.\n" "$B" >/failed; exit 1; }
[[ "$C" = "ENVIRONMENT_FILE" ]] || { printf "Invalid value: '%s'. Expected 'ENVIRONMENT_FILE'.\n" "$C" >/failed; exit 1; }
[[ ! -v "UNKNOWN_VARIABLE" ]] || { printf "UNKNOWN_VARIABLE is set: '%s'.\n" "$UNKNOWN_VARIABLE" >/failed; exit 1; }
[[ ! -v "YOU_CAN_RESET_ME" ]] || { printf "YOU_CAN_RESET_ME is set: '%s'.\n" "$YOU_CAN_RESET_ME" >/failed; exit 1; }
[[ "$YOU_CAN_NOT_RESET_ME" = "CMDLINE" ]] || { printf "Invalid value: '%s'. Expected: 'CMDLINE'\n" "$YOU_CAN_NOT_RESET_ME" >/failed; exit 1; }


show_result=$(systemctl show -p PassEnvironment testsuite.service)
expected_result='PassEnvironment=HIDES_CMDLINE UNKNOWN_VARIABLE HIDES_CONFIG MANAGER_ONLY'

[[ "$show_result" = "$expected_result" ]] || { printf "Invalid value: '%s'. Expected: '%s'" "$show_result" "$expected_result" >/failed; exit 1; }


systemd-run --remain-after-exit \
	--service-type=oneshot \
	--unit=test-systemd-run-pass-environment \
        --property=PassEnvironment='MANAGER_ONLY' \
        --property=PassEnvironment='' \
        --property=PassEnvironment='HIDES_CMDLINE MANAGER_ONLY UNKNOWN_VARIABLE HIDES_CONFIG' \
	/bin/bash -c '[[ "$HIDES_CMDLINE" = "NSPAWN" ]] && [[ "$MANAGER_ONLY" = "MANAGER" ]] && [[ ! -v "UNKNOWN_VARIABLE" ]] && [[ "$HIDES_CONFIG" = "NSPAWN" ]]'


show_result=$(systemctl show -p PassEnvironment test-systemd-run-pass-environment)
expected_result='PassEnvironment=HIDES_CMDLINE MANAGER_ONLY UNKNOWN_VARIABLE HIDES_CONFIG'

[[ "$show_result" = "$expected_result" ]] || { printf "Invalid value: '%s'. Expected: '%s'\n" "$show_result" "$expected_result" >/failed; exit 1; }

systemd-run --property PassEnvironment='MANAGER_ONLY MANAGER_ONLY' /bin/echo && { printf "Unexpected behaviour: PassEnvironment receives the same var two times\n">/failed; exit 1; }

touch /testok
exit 0
