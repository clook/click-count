#!/bin/bash

set -e

MACHINE_NAME=xebia-test
DOMAIN_NAME=xebia-test
CONCOURSE_PREFIX=concourse
REGISTRY_PREFIX=registry

MACHINE_IP=192.168.33.10
BACK_SUBNET=192.168.34.0/28
BACK_GATEWAY=192.168.34.1
DNSMASQ_IP=192.168.34.2


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VAGRANT_CWD="$DIR"

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

# check the machine does not exist or die
check_machine_absent() {
	if ! vagrant 2>/dev/null status default | grep default | grep -q 'not created'; then
		echo 'Vagrant machine already exist, please verify and delete it first.'
		echo "Tip: vagrant destroy"
		exit 4
	fi
}

# create the Vagrant VM
create_machine() {
	vagrant up
}

config_dnsmasq() {
	local machine_ip=$1
	mkdir -p "$DIR"/dnsmasq
	sed -e "s@%DOMAIN_NAME%@${DOMAIN_NAME}@;s@%MACHINE_IP%@${machine_ip}@" \
		-e "s@%DNSMASQ_IP%@${DNSMASQ_IP}@;s@%BACK_SUBNET%@${BACK_SUBNET}@" \
		-e "s@%BACK_GATEWAY%@${BACK_GATEWAY}@" \
		"$DIR"/templates/dnsmasq/docker-compose.yml > "$DIR"/dnsmasq/docker-compose.yml
}

launch_dnsmasq() {
	( cd "$DIR"/dnsmasq && docker-compose up -d )
}

launch_traefik() {
	docker-compose -f "$DIR"/traefik/docker-compose.yml up -d
}

config_concourse() {
	local concourse_host=$CONCOURSE_PREFIX.$DOMAIN_NAME
	local concourse_url=http://$concourse_host
	# Can't use the machine_ip as DNS for a container (NAT issue with Docker?)
	sed "s@%CONCOURSE_HOST%@${concourse_host}@;s@%CONCOURSE_URL%@${concourse_url}@;s@%DNS_SERVER_IP%@${DNSMASQ_IP}@" \
		"$DIR"/templates/concourse/docker-compose.yml > "$DIR"/concourse/docker-compose.yml

	docker volume create --name concourse-db
	docker volume create --name concourse-web-keys
	docker volume create --name concourse-worker-keys
}

launch_concourse() {
	( cd "$DIR"/concourse && docker-compose up -d )
}

config_registry() {
	local registry_host=$REGISTRY_PREFIX.$DOMAIN_NAME

	mkdir -p "$DIR"/registry
	sed "s@%REGISTRY_HOST%@${registry_host}@" \
		"$DIR"/templates/registry/docker-compose.yml > "$DIR"/registry/docker-compose.yml
}

launch_registry() {
	docker-compose -f "$DIR"/registry/docker-compose.yml up -d
}

config_fly() {
	local concourse_host=$CONCOURSE_PREFIX.$DOMAIN_NAME
	local concourse_url=http://$concourse_host
	sed "s@%CONCOURSE_HOST%@${concourse_host}@;s@%CONCOURSE_URL%@${concourse_url}@" \
		"$DIR"/templates/fly/entrypoint.sh > "$DIR"/fly/entrypoint.sh
}

launch_fly() {
	docker build -t alpine-fly "$DIR"/fly
	# Can't use the machine_ip as DNS for a container (NAT issue with Docker?)
	docker run -it --rm --network=dnsmasq_back --dns=${DNSMASQ_IP} alpine-fly
}


main() {
	local bootstrap_type=$1

	if [ "$bootstrap_type" == 'inside' ]; then
		local machine_ip=$MACHINE_IP

		config_dnsmasq $machine_ip
		launch_dnsmasq
		launch_traefik
		config_concourse
		launch_concourse
		config_registry
		launch_registry
		config_fly
		launch_fly

		echo 'Bootstrap ended'
		echo "Please now use $machine_ip as nameserver and try to connect to:"
		echo "- http://$CONCOURSE_PREFIX.$DOMAIN_NAME for concourse"
		echo "- http://$REGISTRY_PREFIX.$DOMAIN_NAME for registry"
		echo "- http://$DOMAIN_NAME:8080 for traefik dashboard"
		echo
	else
		# bootstrap vagrant
		check_vagrant
		check_machine_absent
		create_machine
		vagrant ssh -c '/vagrant/bootstrap_infra.sh inside'
		echo 'You can stop and remove everything by cleaning your resolver and'
		echo "issuing vagrant destroy in the directory $DIR"
		echo
	fi
}

main "$@"
