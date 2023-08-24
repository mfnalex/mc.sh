#!/usr/bin/env sh

# echo to stderr
err() {
	echo >&2 "error: $*"
}

# error exit codes
EXIT_NO_SERVER_NAME=1
EXIT_SERVER_NOT_FOUND=2
EXIT_COULD_NOT_ENTER_FOLDER=3
EXIT_SCREEN_NOT_INSTALLED=4
EXIT_UNKNOWN_ACTION=5
EXIT_CREATED_ENV_FILE=6

# check screen
if ! command -v screen >/dev/null 2>&1; then
	err "command 'screen' not found or not in PATH: ${PATH}"
	exit ${EXIT_SCREEN_NOT_INSTALLED}
fi

# read arguments
SERVER_NAME=$2
ACTION=$1

# env files
GLOBAL_ENV_FILE="${HOME}/mc.env"
SERVER_ENV_FILE_NAME="server.env"

# Create mc.env if not exists, then exit
if [ ! -f "${GLOBAL_ENV_FILE}" ]; then
	echo "Creating global configuration file at ${GLOBAL_ENV_FILE}"
	cat <<-EOF >"${GLOBAL_ENV_FILE}"
		# Path where all servers should be stored (default is \${HOME}/servers)
		SERVERS_BASE_DIRECTORY="${HOME}/servers"

		# The following settings are used as default values for all servers
		# You can override them in each server's own server.env file

		# Screen session name
		# Default: mc-\\\${SERVER_NAME}
		SCREEN_SESSION_NAME=mc-\\\${SERVER_NAME}

		# Maximum RAM for JVM
		# Default: 1G
		XMX=1G

		# Path to java executable
		# Default: /usr/bin/java
		JAVA_PATH=/usr/bin/java

		# Name of the jar file
		# Default: server.jar
		JAR_FILE=server.jar

		# Command to stop the server (without slash, use 'stop' for vanilla/spigot/... and 'end' for bungeecord)
		# Default: stop
		STOP_COMMAND=stop
	EOF
	exit ${EXIT_CREATED_ENV_FILE}
fi

parse_global_env() {
	# Default mc.env
	SERVERS_BASE_DIRECTORY="${HOME}/servers"
	SCREEN_SESSION_NAME="mc-\${SERVER_NAME}"
	XMX=1G
	JAVA_PATH=/usr/bin/java
	JAR_FILE=server.jar
	STOP_COMMAND=stop

	# Read mc.env
	if [ -f "${GLOBAL_ENV_FILE}" ]; then
		set -o allexport
		# shellcheck disable=SC1090
		. "${GLOBAL_ENV_FILE}"
		set +o allexport
	fi
}

parse_server_env() {
	## Read .env
	if [ -f "$1/${SERVER_ENV_FILE_NAME}" ]; then
		set -o allexport
		# shellcheck disable=SC1090
		. "$1/${SERVER_ENV_FILE_NAME}"
		set +o allexport
	fi

	# Evaluate variables
	SCREEN_SESSION_NAME=$(eval echo "${SCREEN_SESSION_NAME}")

	SERVER_DIRECTORY="${SERVERS_BASE_DIRECTORY}/${SERVER_NAME}"
}

parse_all_env() {
	parse_global_env
	SERVER_NAME="$1"
	SERVER_DIRECTORY="${SERVERS_BASE_DIRECTORY}/${SERVER_NAME}"
	parse_server_env "${SERVER_DIRECTORY}"
}

parse_global_env

does_screen_session_exist() {
	if (screen -ls | grep -q "\.$1\s"); then
		return 0
	else
		return 1
	fi
}

get_exact_screen_session_pid_and_name() {
  screen -ls | grep "\.$1\s" | awk '{print $1}'
}

##########################################
# actions not requiring server directory #
##########################################

cd "${SERVERS_BASE_DIRECTORY}" || {
	err "could not enter directory: ${SERVERS_BASE_DIRECTORY}"
	exit ${EXIT_COULD_NOT_ENTER_FOLDER}
}

case ${ACTION} in
list)
	# list all servers
	for SERVER_NAME in *; do
		if [ ! -d "${SERVER_NAME}" ]; then
			continue
		fi
		parse_all_env "${SERVER_NAME}"
		RUNNING="stopped"
		if does_screen_session_exist "${SCREEN_SESSION_NAME}"; then
			RUNNING="running - $(get_exact_screen_session_pid_and_name "${SCREEN_SESSION_NAME}")"
		fi
		echo "${SERVER_NAME} (${RUNNING})"
	done
	exit 0
	;;
esac

# further variables based on mc.env
SERVER_DIRECTORY="${SERVERS_BASE_DIRECTORY}/${SERVER_NAME}"

# check if server name is given
if [ -z "${SERVER_NAME}" ]; then
	err "no server name given"
	exit ${EXIT_NO_SERVER_NAME}
fi

# check if server exists
if [ ! -d "${SERVER_DIRECTORY}" ]; then
	err "server '${SERVER_NAME}' not found at '${SERVER_DIRECTORY}'"
	exit ${EXIT_SERVER_NOT_FOUND}
fi

# enter server directory
cd "${SERVER_DIRECTORY}" || {
	err "could not enter directory: ${SERVER_DIRECTORY}"
	exit ${EXIT_COULD_NOT_ENTER_FOLDER}
}

parse_all_env "${SERVER_NAME}"

# parse actions
case ${ACTION} in
start)
	screen -d -m -S "${SCREEN_SESSION_NAME}" "${JAVA_PATH}" -Xmx${XMX} -jar "${JAR_FILE}"
	;;

stop)
	screen -S "${SCREEN_SESSION_NAME}" -X stuff ${STOP_COMMAND}^M
	;;

attach)
	screen -S "${SCREEN_SESSION_NAME}" -x
	;;
env)
	echo "SERVER_NAME=${SERVER_NAME}"
	echo "SCREEN_SESSION_NAME=${SCREEN_SESSION_NAME}"
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
