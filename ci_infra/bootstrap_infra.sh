#!/bin/bash

set -e

MACHINE_NAME=xebia-test
DOMAIN_NAME=xebia-test
CONCOURSE_PREFIX=concourse
REGISTRY_PREFIX=registry
MACHINE_IP=192.168.33.10

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

# create the docker-machine
create_machine() {
	vagrant up
}

launch_dnsmasq() {
	local machine_ip=$1

	docker run -d -p 53:53/tcp -p 53:53/udp --cap-add=NET_ADMIN --name dnsmasq andyshinn/dnsmasq:2.76 -A /$DOMAIN_NAME/$machine_ip
}

launch_traefik() {
	docker-compose -f "$DIR"/traefik/docker-compose.yml up -d
}

config_concourse() {
	local concourse_host=$CONCOURSE_PREFIX.$DOMAIN_NAME
	local concourse_url=http://$concourse_host
	sed "s@%CONCOURSE_HOST%@${concourse_host}@;s@%CONCOURSE_URL%@${concourse_url}@" \
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

launch_fly() {
	docker build -t alpine-fly "$DIR"/fly
	# Can't use the machine_ip as DNS for a container (NAT issue with Docker?)
	dns_server_ip="$(docker inspect -f '{{.NetworkSettings.IPAddress }}' dnsmasq)"
	docker run -it --rm --dns=$dns_server_ip alpine-fly
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
	dns_server_ip="$(docker inspect -f '{{.NetworkSettings.IPAddress }}' dnsmasq)"
	docker run -it --rm --dns=$dns_server_ip alpine-fly
}


main() {
	local bootstrap_type=$1

	if [ "$bootstrap_type" == 'inside' ]; then
		local machine_ip=$MACHINE_IP

		launch_dnsmasq $machine_ip
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
		echo 'You can stop and remove everything by cleaning your resolver and'
		echo "issuing docker-machine rm $MACHINE_NAME"
		echo
	else
		# bootstrap vagrant
		check_vagrant
		check_machine_absent
		create_machine
		vagrant ssh -c '/vagrant/bootstrap_infra.sh inside'
	fi
}

main "$@"
