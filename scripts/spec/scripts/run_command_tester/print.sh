#/usr/bin/env bash
COUNT=${1:-30}              # print 30 lines to sterr and stdout by default
EXIT_CODE=${2:-0}           # exit with error code 0 by default

for((i=0; i<${COUNT}; i++))
do
    echo -e "\033[32moutput $i\033[0m"
    echo -e "\033[31merror $i\033[m" >&2
done

exit ${EXIT_CODE}
