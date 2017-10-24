#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VAGRANT_CWD="$DIR"

source "$DIR"/ci_infra.conf
source "$DIR"/click-count.ci.conf

# check for variant binary and sanity check or die
check_vagrant() {
	local err=0

	vagrant -h &> /dev/null || err=$?
	if [ "$err" == 127 ]; then
		echo 'This script needs vagrant installed'
		exit 2
	elif [ "$err" != 0 ]; then
		echo 'vagrant unknown error, please check'
		exit 3
	fi
}

# check the machine exists or die
check_machine_present() {
	if vagrant 2>/dev/null status default | grep default | grep -q 'not created'; then
		echo 'Vagrant machine does not exist, please verify.'
		echo "Tip: ./bootstrap_infra.sh"
		exit 4
	fi
}

config_fly() {
	local concourse_host=$CONCOURSE_PREFIX.$DOMAIN_NAME
	local concourse_url=http://$concourse_host
	sed "s@%CONCOURSE_HOST%@${concourse_host}@;s@%CONCOURSE_URL%@${concourse_url}@" \
		"$DIR"/templates/fly/entrypoint.sh > "$DIR"/fly/entrypoint.sh
}

# generate SSH key for fly to call docker on root machine
gen_ssh_fly() {
	rm -f /tmp/sshkey*
	ssh-keygen -b 4096 -t rsa -f /tmp/sshkey -q -N ""
	sudo mkdir -p /root/.ssh
	sudo cp /tmp/sshkey.pub /root/.ssh/authorized_keys
	echo "docker-ssh-key: |" > "$DIR"/fly/pipelines/credentials.yml
	cat /tmp/sshkey | sed 's/^/  /' >> $DIR/fly/pipelines/credentials.yml
	rm -f /tmp/sshkey*
}

# add Redis instances IPs
store_redis_ips() {
	local consul_host=$CONSUL_PREFIX.$DOMAIN_NAME
	
	curl -X PUT -d "$REDIS_HOST_STAGING" http://${consul_host}/v1/kv/click-count-staging/redis_host
	curl -X PUT -d "$REDIS_HOST_PRODUCTION" http://${consul_host}/v1/kv/click-count-production/redis_host
}

launch_fly() {
	docker build -t alpine-fly "$DIR"/fly
	# Can't use the machine_ip as DNS for a container (NAT issue with Docker?)
	docker run -it --rm --network=dnsmasq_back --dns=${DNSMASQ_IP} alpine-fly
}


main() {
	local launch_type=$1

	if [ "$launch_type" == 'inside' ]; then
		local machine_ip=$MACHINE_IP

		config_fly
		gen_ssh_fly
		store_redis_ips
		launch_fly

		echo 'CI click-count ended'
		echo
		echo "Please now use $machine_ip as nameserver and try to connect to:"
		echo "- http://staging.$APP_NAME.$DOMAIN_NAME for staging app (when built)"
		echo "- http://$APP_NAME.$DOMAIN_NAME for production app (when built)"
		echo
	else
		# check vagrant
		check_vagrant
		check_machine_present
		vagrant ssh -c '/vagrant/launch_ci.sh inside'
		echo 'You can stop and remove everything by cleaning your resolver and'
		echo "issuing vagrant destroy in the directory $DIR"
		echo
	fi
}

main "$@"
