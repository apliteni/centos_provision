#/usr/bin/env bash
STDOUT_FILE="${1}"
STDERR_FILE="${2}"
EXIT_CODE=${3:-0}

echo -e "\033[32m$(cat ${STDOUT_FILE})\033[0m"
echo -e "\033[31m$(cat ${STDERR_FILE})\033[0m" >&2

exit ${EXIT_CODE}
