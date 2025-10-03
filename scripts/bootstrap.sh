#!/bin/bash
set -e

# uncomment to debug
# set -x

EXAMPLES_DIR="examples"
ARGOCD_NS="openshift-gitops"

source "$(dirname "$0")/functions.sh"

choose_example(){
    examples_dir=${EXAMPLES_DIR}

    echo
    echo "Choose an example you wish to deploy?"
    PS3="Please enter a number to select an example folder: "

    select chosen_example in $(basename -a ${examples_dir}/*/); 
    do
    test -n "${chosen_example}" && break;
    echo ">>> Invalid Selection";
    done

    echo "You selected ${chosen_example}"

    CHOSEN_EXAMPLE_PATH=${examples_dir}/${chosen_example}
}

choose_example_option(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to choose_example_option()"
        echo "Usage: choose_example_option <chosen_example_path>"
        exit 1
    fi
    chosen_example_path=$1

    echo

    # Find all unique overlay options across all overlays directories
    all_overlay_options=$(find "${chosen_example_path}" -mindepth 3 -maxdepth 3 -type d -path "*/overlays/*" -exec basename {} \; | sort -u)
    
    if [ -z "$all_overlay_options" ]; then
        echo "No overlays folder was found matching pattern: ${chosen_example_path}/*/overlays"
        exit 2
    fi
    unique_overlay_count=$(echo "$all_overlay_options" | wc -l)
    
    if [ "$unique_overlay_count" -gt 1 ]; then
        # Multiple unique overlay options found across all directories
        # let the user choose which one to deploy
        echo "Multiple unique overlay options found across all directories:"
        echo "$all_overlay_options"
        echo
        PS3="Choose an option you wish to deploy?"
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
    else
        echo "No overlay options found in any overlays directory"
        exit 2
    fi

    CHOSEN_EXAMPLE_OPTION_PATH="${chosen_example_path}/*/overlays/${chosen_option}"
}

deploy_example(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to deploy_example()"
        echo "Usage: deploy_example <chosen_example_overlay_path>"
        exit 1
    fi
    chosen_example_overlay_path="$1"

    # Extract the example name from the path (second component after splitting by "/")
    example_name=$(echo "${chosen_example_overlay_path}" | cut -d'/' -f2)

    echo
    echo "Example name: ${example_name}"
    echo "GITHUB_URL: ${GITHUB_URL}"
    echo "GIT_BRANCH: ${GIT_BRANCH}"
    echo "chosen_example_overlay_path: ${chosen_example_overlay_path}"
    echo

    helm upgrade -i ${example_name} ./charts/argocd-appgenerator -n ${ARGOCD_NS} \
        --set fullnameOverride=${example_name} \
        --set repoURL=${GITHUB_URL} \
        --set revision=${GIT_BRANCH} \
        --set directories[0].path="${chosen_example_overlay_path}"
}


set_repo_url(){
    GIT_REPO=$(git config --get remote.origin.url)
    GIT_REPO_BASENAME=$(get_git_basename ${GIT_REPO})
    GITHUB_URL="https://github.com/${GIT_REPO_BASENAME}.git"
    
    echo
    echo "Current repository URL: ${GITHUB_URL}"
    echo
    read -p "Press Enter to use this URL, or enter a new repository URL: " user_input
    
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
    read -p "Press Enter to use this branch, or enter a new repository branch: " user_input
    
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
    choose_example
    choose_example_option "${CHOSEN_EXAMPLE_PATH}"
    deploy_example "${CHOSEN_EXAMPLE_OPTION_PATH}"
}

# check_oc_login
main
