#!/usr/bin/env bash

################################################################################
# Error handling
################################################################################

set -eu
set -o pipefail
set -o posix

set -C

################################################################################
# Script information
################################################################################

# Readlink recursively
# 
# This can be achieved with `readlink -f` in the GNU command environment,
# but we implement it independently for mac support.
#
# Arguments
#   $1 - target path
#
# Standard Output
#   the absolute real path
function itr_readlink() {
    local target_path=$1

    (
        cd "$(dirname "$target_path")"
        target_path=$(basename "$target_path")

        # Iterate down a (possible) chain of symlinks
        while [ -L "$target_path" ]
        do
            target_path=$(readlink "$target_path")
            cd "$(dirname "$target_path")"
            target_path=$(basename "$target_path")
        done

        echo "$(pwd -P)/$target_path"
    )
}

# The current directory when this script started.
# ORIGINAL_PWD=$(pwd)
# readonly ORIGINAL_PWD
# The path of this script file
SCRIPT_PATH=$(itr_readlink "$0")
readonly SCRIPT_PATH
# The directory path of this script file
SCRIPT_DIR=$(cd "$(dirname "$SCRIPT_PATH")"; pwd)
readonly SCRIPT_DIR
# The path of this script file
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
readonly SCRIPT_NAME

# The version number of this application
GPDF_VERSION=$(cat "$SCRIPT_DIR/.gpdf.version")
export GPDF_VERSION
readonly GPDF_VERSION
# Application name
GPDF_APP_NAME="Grafana to PDF"
export GPDF_APP_NAME
readonly GPDF_APP_NAME
# Application name
GPDF_APP_NAME_SHORTAGE="gpdf"
export GPDF_APP_NAME_SHORTAGE
readonly GPDF_APP_NAME_SHORTAGE


################################################################################
# Functions
################################################################################

function usage_exit () {
    echo "Usage:" "$(basename "$0") --template <template_name> [--url-query <query>] <dashboard_uid> [...]" 1>&2
    exit "$1"
}

function echo_version() {
    echo "$GPDF_APP_NAME $GPDF_VERSION"
}

function echo_help () {
    echo "Usage:" "$(basename "$0") --template <template_name> [--url-query <query>] <dashboard_uid> [...]"
    echo ""
    echo "Options"
    echo "    --template <template_name> :"
    echo "         (Required) Name of tex template to use. If specified,"
    echo "         \"\$REPORTER_TEMPLATE_DIR/<template_name>.tex\" is used as the template."
    echo "    --url-query <query> :"
    echo "         (Optional) A string given to the dashboard as a URL query. It can be"
    echo "         used to pass dashboard variables. Refer to the right side of '?' in the"
    echo "         URL of dashboards."
    echo "         For example: from=now-1h&to=now&var-RecordID=1"
    echo ""
    echo "Arguments"
    echo "    <dashboard_uid> [...] :"
    echo "         (Required) UID of dashboards you want to output as PDF"
    echo ""
    echo "Environment variables"
    echo "    GRAFANA_HOST :"
    echo "         (Required) The host and port of target Grafana server."
    echo "         For example: grafana.example.com:3000"
    echo "    GRAFANA_KEY_PATH :"
    echo "         (Required) Path of the file that contains the api key to access"
    echo "         Grafana."
    echo "    REPORTER_TEMPLATE_DIR :"
    echo "         (Required) Directory path where template files are stored."
    echo "    REPORTER_DEST_DIR :"
    echo "         (Required) Directory path where PDF files are output."
}

# Output an information
#
# Because stdout is used as output of gradle in this script,
# any messages should be output to stderr.
function echo_info () {
    echo "$SCRIPT_NAME: $*" >&2
}

# Output an error
#
# Because stdout is used as output of gradle in this script,
# any messages should be output to stderr.
function echo_err() {
    echo "$SCRIPT_NAME: $*" >&2
}

################################################################################
# Constant values
################################################################################


################################################################################
# Analyze arguments
################################################################################
declare -i argc=0
declare -a argv=()
template_name=
url_query=
version_flg=1
help_flg=1
invalid_option_flg=1
while (( $# > 0 )); do
    case $1 in
        -)
            ((++argc))
            argv+=( "$1" )
            shift
            ;;
        -*)
            if [[ "$1" == '--template' ]]; then
                template_name="$2"
                shift
            elif [[ "$1" == '--url-query' ]]; then
                url_query="$2"
                shift
            elif [[ "$1" == "--version" ]]; then
                version_flg=0
            elif [[ "$1" == "--help" ]]; then
                help_flg=0
                # Ignore other arguments when displaying help
                break
            else
                # The option is illegal.
                # In some cases, such as when --help is specified, illegal options may be ignored,
                # so do not exit immediately, but only flag them.
                invalid_option_flg=0
            fi
            shift
            ;;
        *)
            ((++argc))
            argv+=( "$1" )
            shift
            ;;
    esac
done
exit_code=$?
if [ $exit_code -ne 0 ]; then
    exit $exit_code
fi

if [ "$help_flg" -eq 0 ]; then
    echo_help
    exit 0
fi

if [ "$version_flg" -eq 0 ]; then
    echo_version
    exit 0
fi

if [ "$invalid_option_flg" -eq 0 ]; then
    usage_exit 1
fi

if [ "$argc" -lt 1 ]; then
    usage_exit 1
fi

readonly dashboard_uid_list=("${argv[@]}")

if [ -z "$template_name" ]; then
    usage_exit 1
else
    readonly template_name
fi

readonly url_query


################################################################################
# Validate arguments
################################################################################


################################################################################
# Temporally files
################################################################################

# All temporally files which should be deleted on exit
tmpfile_list=( )

function remove_tmpfile {
    set +e
    for tmpfile in "${tmpfile_list[@]}"
    do
        if [ -e "$tmpfile" ]; then
            rm -f "$tmpfile"
        fi
    done
    set -e
}
trap remove_tmpfile EXIT
trap 'trap - EXIT; remove_tmpfile; exit -1' INT PIPE TERM


################################################################################
# main
################################################################################

grafana_api_key=$(cat "$GRAFANA_KEY_PATH")
readonly grafana_api_key

for dashboard_uid in "${dashboard_uid_list[@]}"; do
    grafana-reporter -cmd_enable -cmd_apiVersion v5 \
        -ip "$GRAFANA_HOST" \
        -cmd_apiKey "$grafana_api_key" \
        -grid-layout \
        -cmd_dashboard "$dashboard_uid"  \
        -templates "$REPORTER_TEMPLATE_DIR" \
        -cmd_template "$template_name" \
        -cmd_ts "${url_query}&from=now-1M/M&to=now-1M/M" \
        -cmd_o "$REPORTER_DEST_DIR/$dashboard_uid.pdf"
done
