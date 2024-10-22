#!/bin/bash

set -e
set -o pipefail

log_file="${CPU_TEMP_LOG_FILE:-/var/log/cpu-temp.log}"
cpu_temp_threshold="${CPU_TEMP_THRESHOLD:-65}"
shutdown_cmd="${SHUTDOWN_COMMAND:-}"
delay_seconds=60

get_cpu_temp() {
	awk '{ print int($1 / 1000) }' < /sys/class/thermal/thermal_zone0/temp
}

now() {
	date +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\(..\)$/:\1/'
}

terminate() {
	echo >&2 Terminating
	exit 0
}

shutdown() {
	if [[ -n "${shutdown_cmd}" ]]; then
		${shutdown_cmd}
	fi
}

log() {
	timestamp="$1"
	cpu_temp="$2"
	action="$3"
	if [[ -z "${action}" ]]; then
		echo "{\"timestamp\": \"${timestamp}\", \"cpu_temp\": \"${cpu_temp}\"}"
	else
		echo "{\"timestamp\": \"${timestamp}\", \"cpu_temp\": \"${cpu_temp}\", \"action\": \"${action}\"}"
	fi
}

main() {
	local cpu_temp=""
	local timestamp=""
	local action=""
	while true; do
		timestamp="$(now)"
		cpu_temp="$(get_cpu_temp)"
		action=""

		if (( cpu_temp > cpu_temp_threshold )); then
			action="shutdown"
		fi
		log "${timestamp}" "${cpu_temp}" "${action}" | tee /dev/stderr
		if [[ "${action}" == "shutdown" ]]; then
			shutdown
		fi
		# This allows for quicker reaction to signals.
		for _ in $(seq "${delay_seconds}"); do
			sleep 1
		done
	done
}

trap terminate SIGTERM SIGINT
main >> "${log_file}"
