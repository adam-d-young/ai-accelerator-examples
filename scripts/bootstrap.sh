#!/usr/bin/env bash
set -euo pipefail

# uncomment to debug
# set -x

EXAMPLES_DIR="examples"
ARGOCD_NS="openshift-gitops"

# shellcheck source=./functions.sh
source "$(dirname "$0")/functions.sh"

choose_example(){
    examples_dir=${EXAMPLES_DIR}

    echo
    echo "Choose an example you wish to deploy:"
    PS3="Please enter a number to select an example folder (enter q to exit): "

    select chosen_example in $(find "${examples_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort);
    do
        # Check if user wants to quit
        if [[ "$REPLY" == [qQ] ]]; then
            return 2 # exit code for q
        fi
        test -n "${chosen_example}" && break;
        echo ">>> Invalid Selection";
    done

    echo "You selected ${chosen_example}"

    CHOSEN_EXAMPLE_PATH=${examples_dir}/${chosen_example}
}

choose_example_kustomize_option(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to choose_example_kustomize_option()"
        echo "Usage: choose_example_kustomize_option <chosen_example_path>"
        exit 1
    fi
    chosen_example_path=$1

    echo

    # Find all unique overlay options across all overlays directories
    all_overlay_options=$(find "${chosen_example_path}" -mindepth 3 -maxdepth 3 -type d -path "*/overlays/*" -exec basename {} \; | sort -u)
    
    if [ -n "$all_overlay_options" ]; then
        unique_overlay_count=$(echo "$all_overlay_options" | wc -l)
        
        if [ "$unique_overlay_count" -gt 1 ]; then
            # Multiple unique overlay options found across all directories
            # let the user choose which one to deploy
            echo "Multiple unique overlay options found:"
            echo "$all_overlay_options"
            echo
            PS3="Choose an option you wish to deploy:"
            select chosen_option in $all_overlay_options;
            do
                test -n "${chosen_option}" && break;
                echo ">>> Invalid Selection";
            done
            echo "You selected ${chosen_option}"
        elif [ "$unique_overlay_count" -eq 1 ]; then
            # Only one unique overlay option found
            chosen_option="$all_overlay_options"
            echo "Only one unique overlay option found: ${chosen_option}"
        fi

        CHOSEN_EXAMPLE_OPTION_PATH="${chosen_example_path}/*/overlays/${chosen_option}"
    else
        if [ -n "${chosen_example_path}/helm-charts" ]; then
            echo "No overlays folder was found, but helm-charts folder was found"
            CHOSEN_EXAMPLE_OPTION_PATH=""
        else
            echo "No overlays folder was found matching pattern: ${chosen_example_path}/*/overlays"
            echo "No helm-charts folder was found matching pattern: ${chosen_example_path}/helm-charts"
            exit 2
        fi
    fi

}

deploy_example(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to deploy_example()"
        echo "Usage: deploy_example <example_name>"
        exit 1
    fi
    chosen_example_path="${1}"
    chosen_example_overlay_path="${2:-""}"

    # Extract the example name from the path (second component after splitting by "/")
    example_name=$(echo "${chosen_example_path}" | cut -d'/' -f2)

    echo
    echo "Example name: ${example_name}"
    echo "GITHUB_URL: ${GITHUB_URL}"
    echo "GIT_BRANCH: ${GIT_BRANCH}"
    echo "chosen_example_overlay_path: ${chosen_example_overlay_path}"
    echo

    CLUSTER_DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

    helm upgrade -i "${example_name}" ./charts/argocd-appgenerator -n "${ARGOCD_NS}" \
        --set fullnameOverride="${example_name}" \
        --set repoURL="${GITHUB_URL}" \
        --set targetRevision="${GIT_BRANCH}" \
        --set clusterDomainUrl="${CLUSTER_DOMAIN_NAME}" \
        --set "kustomizeDirectories[0].path=${chosen_example_overlay_path}" \
        --set "helmDirectories[0].path=${chosen_example_path}/helm-charts/**"
}

set_repo_url(){
    GITHUB_URL=$(get_git_basename)

    echo
    echo "Current repository URL: ${GITHUB_URL}"
    echo
    read -r -p "Press Enter to use this URL, or enter a new repository URL: " user_input

    if [ -n "$user_input" ]; then
        GITHUB_URL="$user_input"
        echo "Updated repository URL to: ${GITHUB_URL}"
    else
        echo "Using repository URL: ${GITHUB_URL}"
    fi
}

set_repo_branch(){
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    echo
    echo "Current repository branch: ${GIT_BRANCH}"
    echo
    read -r -p "Press Enter to use this branch, or enter a new repository branch: " user_input

    if [ -n "$user_input" ]; then
        GIT_BRANCH="$user_input"
        echo "Updated repository branch to: ${GIT_BRANCH}"
    else
        echo "Using repository branch: ${GIT_BRANCH}"
    fi
}

main(){
    set_repo_url
    set_repo_branch

    while true; do
        exit_code=0
        choose_example || exit_code=$?
        if [ "${exit_code:-0}" -eq 2 ]; then # user selected q/Q
            echo "Exiting..."
            break
        fi
        choose_example_kustomize_option "${CHOSEN_EXAMPLE_PATH}"
        deploy_example  "${CHOSEN_EXAMPLE_PATH}" "${CHOSEN_EXAMPLE_OPTION_PATH}"
    done
}

# check_oc_login
main
