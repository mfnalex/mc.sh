#!/usr/bin/env sh

# echo to stderr
function err() {
    >&2 echo "error: $@"
}

# error exit codes
EXIT_NO_SERVERNAME=1
EXIT_SERVER_NOT_FOUND=2
EXIT_COULDNT_ENTER_FOLDER=3
EXIT_SCREEN_NOT_INSTALLED=4
EXIT_UNKNOWN_ACTION=5

# read arguments
SERVER_NAME=$1
ACTION=$2

# this needs to be configurable in user's main mc.env
SERVERS_BASE_DIRECTORY="~/servers"

# further variables we need later on
SERVER_DIRECTORY="${SERVERS_BASE_DIRECTORY}/${SERVER_NAME}"

# check screen
if ! command -v screen &> /dev/null
then
    err "command 'screen' not found or not in PATH: ${PATH}"
    exit ${EXIT_SCREEN_NOT_INSTALLED}
fi

# check if server name is given
if [ -z ${SERVER_NAME} ]; then
        err "no server name given"
        exit ${EXIT_NO_SERVERNAME}
fi

# check if server exists
if [ ! -d "${SERVER_DIRECTORY}" ]; then
        err "server '${SERVER_NAME}' not found at '${SERVER_DIRECTORY}'"
        exit ${EXIT_SERVER_NOT_FOUND}
fi

# enter server directory
cd "${SERVER_DIRECTORY}" || {
    err "could not enter directory: ${SERVER_DIRECTORY}";
    exit ${EXIT_COULDNT_ENTER_FOLDER};
}


## Default .env
XMX=1G
JAVA_PATH=/usr/bin/java
JAR_FILE=server.jar
STOP_COMMAND=stop


## Read .env
if [ -f server.env ]; then
set -o allexport
. ./server.env
set +o allexport
fi




case ${ACTION} in
        start)
#                echo "starting ${SERVER_NAME}"
                screen -d -m -S mc-${SERVER_NAME} ${JAVA_PATH} -Xmx${XMX} -jar ${JAR_FILE}
                ;;

        stop)
#                echo "stopping ${SERVER_NAME}"
                screen -S mc-${SERVER_NAME} -X stuff ${STOP_COMMAND}^M
                ;;

        attach)
#                echo "attaching ${SERVER_NAME}"
                screen -S mc-${SERVER_NAME} -x
                ;;
        info)
                echo "SERVER_NAME=${SERVER_NAME}"
                echo "XMX=${XMX}"
                echo "JAVA_PATH=${JAVA_PATH}"
                echo "JAR_FILE=${JAR_FILE}"
                echo "STOP_COMMAND=${STOP_COMMAND}"
                ;;
        *)
                err "unknown action: ${ACTION}"
                exit ${EXIT_UNKNOWN_ACTION}
                ;;
esac