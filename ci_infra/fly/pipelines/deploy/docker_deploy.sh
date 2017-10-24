#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ref_file="$DIR"/../../../../.git/ref

if [ -f "$ref_file" ]; then
	docker_tag=$(cat "$ref_file")
else
	echo "Can't find git revision"
	exit 1
fi

if [ "$DEPLOY_ENV" == "production" ]; then
	host_name=click-count
else
	host_name=staging.click-count
fi

mkdir -p ~/.ssh/

# replace "  " by \n
echo ${SSH_KEY} | sed -e 's/\(KEY-----\)\s/\1\n/g; s/\s\(-----END\)/\n\1/g' | sed -e '2s/\s\+/\n/g' > ~/.ssh/id_rsa_app
chmod 600 ~/.ssh/id_rsa_app

ansible-playbook deploy-app.yml \
	-e env="${DEPLOY_ENV}" \
	-e docker_tag="$docker_tag" \
	-e host_name="$host_name" \
	-e host_consul="$HOST_CONSUL" \
	--private-key ~/.ssh/id_rsa_app \
	-i hosts/${DEPLOY_ENV} -u root
