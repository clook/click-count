#!/bin/bash

set -e

MACHINE_NAME=xebia-test
DOMAIN_NAME=xebia-test

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

	docker run -d -p 53:53/tcp -p 53:53/udp --cap-add=NET_ADMIN andyshinn/dnsmasq:2.76 -A /$DOMAIN_NAME/$machine_ip
}

launch_traefik() {
	docker-compose -f "$DIR"/traefik/docker-compose.yml up -d
}

config_whoami() {
	mkdir -p "$DIR"/whoami
	cat > "$DIR"/whoami/docker-compose.yml << EOF
version: '2'

services:
  whoami:
    image: emilevauge/whoami
    networks:
      - web
    labels:
      - "traefik.backend=whoami"
      - "traefik.frontend.rule=Host:whoami.$DOMAIN_NAME"

networks:
  web:
    external:
      name: traefik_webgateway
EOF
}

launch_whoami() {
	docker-compose -f "$DIR"/whoami/docker-compose.yml up -d --scale whoami=2
}


main() {
	check_docker_machine
	check_machine_absent
	create_machine

	local machine_ip=$(docker-machine ip $MACHINE_NAME)
	eval $(docker-machine env $MACHINE_NAME)

	launch_dnsmasq $machine_ip
	launch_traefik
	config_whoami
	launch_whoami

	echo 'Bootstrap ended'
	echo "Please now use $machine_ip as nameserver and try to connect to:"
	echo "- http://whoami.$DOMAIN_NAME for whoami"
	echo "- http://$DOMAIN_NAME:8080 for traefik dashboard"
	echo
	echo 'You can stop and remove everything by cleaning your resolver and'
	echo "issuing docker-machine rm $MACHINE_NAME"
	echo
}

main
