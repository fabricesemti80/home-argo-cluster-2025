#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"

function wait_for_node_ready() {
    local node_name="${1}"
    local timeout_seconds="${2}"
    local start_time
    start_time="$(date +%s)"

    log info "Waiting for node to report Ready" "node=${node_name}" "timeout_seconds=${timeout_seconds}"

    while true; do
        if kubectl get node "${node_name}" &>/dev/null; then
            local ready_status
            ready_status="$(kubectl get node "${node_name}" -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}')"
            if [[ "${ready_status}" == "True" ]]; then
                log info "Node is Ready again" "node=${node_name}"
                return 0
            fi
        fi

        if (( "$(date +%s)" - start_time > timeout_seconds )); then
            log error "Timed out waiting for node readiness" "node=${node_name}" "timeout_seconds=${timeout_seconds}"
        fi

        sleep 10
    done
}

function restart_vm() {
    local proxmox_host="${1}"
    local vm_id="${2}"
    local node_name="${3}"
    local settle_seconds="${4}"
    local timeout_seconds="${5}"
    local ssh_identity_file="${6}"

    log info "Restarting VM through Proxmox" "proxmox_host=${proxmox_host}" "vm_id=${vm_id}" "node=${node_name}"
    if [[ -n "${ssh_identity_file}" ]]; then
        ssh -i "${ssh_identity_file}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${proxmox_host}" "qm reboot ${vm_id}"
    else
        ssh "${proxmox_host}" "qm reboot ${vm_id}"
    fi

    log info "Waiting for reboot to settle before health checks" "node=${node_name}" "settle_seconds=${settle_seconds}"
    sleep "${settle_seconds}"

    wait_for_node_ready "${node_name}" "${timeout_seconds}"
}

function main() {
    check_cli kubectl ssh

    local settle_seconds="${SETTLE_SECONDS:-20}"
    local timeout_seconds="${TIMEOUT_SECONDS:-900}"
    local role_filter="${ROLE:-all}"
    local ssh_identity_file="${SSH_IDENTITY_FILE:-}"

    local -a vm_ids=(4093 4094 4095 4090 4091 4092)
    local -a proxmox_hosts=(
        "root@10.0.40.10"
        "root@10.0.40.11"
        "root@10.0.40.12"
        "root@10.0.40.10"
        "root@10.0.40.11"
        "root@10.0.40.12"
    )
    local -a node_names=(
        "k8s-wrkr-01"
        "k8s-wrkr-02"
        "k8s-wrkr-03"
        "k8s-ctrl-01"
        "k8s-ctrl-02"
        "k8s-ctrl-03"
    )

    local count="${#vm_ids[@]}"
    for ((i = 0; i < count; i++)); do
        if [[ "${role_filter}" == "workers" && "${node_names[$i]}" != k8s-wrkr-* ]]; then
            continue
        fi

        if [[ "${role_filter}" == "controllers" && "${node_names[$i]}" != k8s-ctrl-* ]]; then
            continue
        fi

        restart_vm "${proxmox_hosts[$i]}" "${vm_ids[$i]}" "${node_names[$i]}" "${settle_seconds}" "${timeout_seconds}" "${ssh_identity_file}"
    done

    log info "Completed rolling Proxmox restart" "role=${role_filter}"
}

main "$@"
