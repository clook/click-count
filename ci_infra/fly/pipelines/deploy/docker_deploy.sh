#!/bin/bash

set -e

mkdir -p ~/.ssh/
echo ${SSH_KEY} | sed -e 's/\(KEY-----\)\s/\1\n/g; s/\s\(-----END\)/\n\1/g' | sed -e '2s/\s\+/\n/g' > ~/.ssh/id_rsa_app
chmod 600 ~/.ssh/id_rsa_app
ansible-playbook deploy-app.yml -e env="${DEPLOY_ENV}" --private-key ~/.ssh/id_rsa_app -i hosts/${DEPLOY_ENV} -u root


#docker version

#docker pull ${repository}

#docker service rm ${serviceName} || true

#docker service create \
#	--name=${serviceName} \
#	--network=${network} \
#	${repository}
		

#echo '{ "version": { "ref": "'$BUILD_ID'" } }' >&3
