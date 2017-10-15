#!/bin/bash

set -e

MACHINE_NAME=xebia-test
DOMAIN_NAME=xebia-test
CONCOURSE_PREFIX=concourse

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# check for docker-machine binary and sanity check or die
check_docker_machine() {
	local err=0

	docker-machine &> /dev/null || err=$?
	if [ "$err" == 127 ]; then
		echo 'This script needs docker-machine installed'
		exit 2
	elif [ "$err" != 0 ]; then
		echo 'docker-machine unknown error, please check'
		exit 3
	fi
}

# check the machine $MACHINE_NAME does not exist or die
check_machine_absent() {
	if docker-machine status $MACHINE_NAME &> /dev/null; then
		echo 'docker-machine already exist, please verify and delete it first.'
		echo "Tip: docker-machine rm $MACHINE_NAME"
		exit 4
	fi
}

# create the docker-machine
create_machine() {
	docker-machine create --driver virtualbox $MACHINE_NAME
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

config_fly() {
	local concourse_host=$CONCOURSE_PREFIX.$DOMAIN_NAME
	local concourse_url=http://$concourse_host
	sed "s@%CONCOURSE_HOST%@${concourse_host}@;s@%CONCOURSE_URL%@${concourse_url}@" \
		"$DIR"/templates/fly/entrypoint.sh > "$DIR"/fly/entrypoint.sh
}

launch_fly() {
	docker build -t alpine-fly "$DIR"/fly
    dns_server_ip="$(docker inspect -f '{{.NetworkSettings.IPAddress }}' dnsmasq)"
    docker run -it --rm --dns=$dns_server_ip alpine-fly
}


main() {
	check_docker_machine
	check_machine_absent
	create_machine

	local machine_ip=$(docker-machine ip $MACHINE_NAME)
	eval $(docker-machine env $MACHINE_NAME)

	launch_dnsmasq $machine_ip
	launch_traefik
	config_concourse
	launch_concourse
	config_fly
	launch_fly

	echo 'Bootstrap ended'
	echo "Please now use $machine_ip as nameserver and try to connect to:"
	echo "- http://concourse.$DOMAIN_NAME for concourse"
	echo "- http://$DOMAIN_NAME:8080 for traefik dashboard"
	echo
	echo 'You can stop and remove everything by cleaning your resolver and'
	echo "issuing docker-machine rm $MACHINE_NAME"
	echo
}

main
