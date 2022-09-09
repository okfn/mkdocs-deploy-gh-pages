#!/bin/bash

set -e

function print_info() {
    echo -e "\e[36mINFO: ${1}\e[m"
}

for package in ${EXTRA_PACKAGES}
do
    apk add --no-cache "${package}"
done

if [ -n "${REQUIREMENTS}" ] && [ -f "${GITHUB_WORKSPACE}/${REQUIREMENTS}" ]; then
    pip install -r "${GITHUB_WORKSPACE}/${REQUIREMENTS}"
else
    REQUIREMENTS="${GITHUB_WORKSPACE}/requirements.txt"
    if [ -f "${REQUIREMENTS}" ]; then
        pip install -r "${REQUIREMENTS}"
    fi
fi

if [ -n "${CUSTOM_DOMAIN}" ]; then
    print_info "Setting custom domain for github pages"
    echo "${CUSTOM_DOMAIN}" > "${GITHUB_WORKSPACE}/docs/CNAME"
fi

if [ -n "${CONFIG_FILE}" ]; then
    print_info "Setting custom path for mkdocs config yml"
    export CONFIG_FILE="${GITHUB_WORKSPACE}/${CONFIG_FILE}"
else
    export CONFIG_FILE="${GITHUB_WORKSPACE}/mkdocs.yml"
fi

if [ -n "${GITHUB_TOKEN}" ]; then
    print_info "setup with GITHUB_TOKEN"
    remote_repo="https://x-access-token:${GITHUB_TOKEN}@${GITHUB_DOMAIN:-"github.com"}/${GITHUB_REPOSITORY}.git"
elif [ -n "${PERSONAL_TOKEN}" ]; then
    print_info "setup with PERSONAL_TOKEN"
    remote_repo="https://x-access-token:${PERSONAL_TOKEN}@${GITHUB_DOMAIN:-"github.com"}/${GITHUB_REPOSITORY}.git"
else
    print_info "no token found; linting"
    exec -- mkdocs build --config-file "${CONFIG_FILE}" --strict
fi

# workaround, see https://github.com/actions/checkout/issues/766
git config --global --add safe.directory "$GITHUB_WORKSPACE"

if ! git config --get user.name; then
    git config --global user.name "${GITHUB_ACTOR}"
fi

if ! git config --get user.email; then
    git config --global user.email "${GITHUB_ACTOR}@users.noreply.${GITHUB_DOMAIN:-"github.com"}"
fi

git remote rm origin
git remote add origin "${remote_repo}"

# Allow multiple config files (multi language)
# shellcheck disable=SC2153
if [ -n "${CONFIG_FILES}" ]; then

    TOTAL=$(echo "$CONFIG_FILES" | wc -w)
    # shellcheck disable=SC2206
    FILES=($CONFIG_FILES)

    for ((i = 1; i <= TOTAL; i++))
    do
        
        CONFIG_FILE="${GITHUB_WORKSPACE}/${FILES[$i-1]}"

        # First one is clean (not --dirty)
        if [ "$i" -eq "0" ]; then
            echo "BUILDING FIRST CONFIG: ${CONFIG_FILE}"
            mkdocs build --config-file "${CONFIG_FILE}"
        elif [ "$i" -eq "$TOTAL" ]; then
            # last one includes a deploy
            echo "BUILDING AND DEPLOY LAST CONFIG: ${CONFIG_FILE}"
            mkdocs gh-deploy --config-file "${CONFIG_FILE}" --force --dirty
        else
            # intermediate single builds and are dirty
            echo "BUILDING $i config file: ${CONFIG_FILE}"
            mkdocs build --config-file "${CONFIG_FILE}" --dirty
        fi

    done
else
    mkdocs gh-deploy --config-file "${CONFIG_FILE}"
fi
