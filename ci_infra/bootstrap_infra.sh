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
DNSNET_WORKER_IP=192.168.34.3


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
	local nameserver_ip=$2

	mkdir -p "$DIR"/dnsmasq

	sed -e "s@%DOMAIN_NAME%@${DOMAIN_NAME}@;s@%MACHINE_IP%@${machine_ip}@" \
		-e "s@%DNSMASQ_IP%@${DNSMASQ_IP}@;s@%BACK_SUBNET%@${BACK_SUBNET}@" \
		-e "s@%BACK_GATEWAY%@${BACK_GATEWAY}@;s@%NAMESERVER_IP%@${nameserver_ip}@" \
		"$DIR"/templates/dnsmasq/docker-compose.yml > "$DIR"/dnsmasq/docker-compose.yml
}

launch_dnsmasq() {
	( cd "$DIR"/dnsmasq && docker-compose up -d )
}

# enforce usage of dnsmasq, disable dhclient resolv.conf update
# => this will keep domain-name-servers unchanged in lease file, as well
apply_dns_config() {
	local nameserver_ip=$1
	cat << EOF | sudo tee /etc/dhcp/no_resolv_conf_update
#!/bin/sh
make_resolv_conf() {
:
}
EOF
	sudo ln -sf ../no_resolv_conf_update /etc/dhcp/dhclient-enter-hooks.d/
	# no need to restart, the hook will be taken in account for next lease

	echo -e "nameserver ${nameserver_ip}\nnameserver 127.0.0.1" | sudo tee /etc/resolv.conf
}

launch_traefik() {
	docker-compose -f "$DIR"/traefik/docker-compose.yml up -d
}

config_concourse() {
	local concourse_host=$CONCOURSE_PREFIX.$DOMAIN_NAME
	local concourse_url=http://$concourse_host
	# Can't use the machine_ip as DNS for a container (NAT issue with Docker?)
	sed -e "s@%CONCOURSE_HOST%@${concourse_host}@;s@%CONCOURSE_URL%@${concourse_url}@" \
		-e "s@%DNS_SERVER_IP%@${DNSMASQ_IP}@;s@%DNSNET_WORKER_IP%@${DNSNET_WORKER_IP}@" \
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

# Launch registry and update docker config
launch_registry() {
	docker-compose -f "$DIR"/registry/docker-compose.yml up -d
	echo "{ \"insecure-registries\":[\"$REGISTRY_PREFIX.$DOMAIN_NAME:80\"] }" | sudo tee >/dev/null /etc/docker/daemon.json
	sudo systemctl reload docker
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

launch_fly() {
	docker build -t alpine-fly "$DIR"/fly
	# Can't use the machine_ip as DNS for a container (NAT issue with Docker?)
	docker run -it --rm --network=dnsmasq_back --dns=${DNSMASQ_IP} alpine-fly
}


main() {
	local bootstrap_type=$1

	if [ "$bootstrap_type" == 'inside' ]; then
		local machine_ip=$MACHINE_IP

		# Get expected nameserver from lease file to be given to dnsmasq
		#local leases_file=$(ps -A -o cmd | grep -o '/var/lib/dhcp/dhclient\.\w*\.leases')
		#local nameserver_ip=$(grep 'option domain-name-servers ' $leases_file | tail -n 1 | awk '{ print $3 }' | cut -d\; -f1)
		# Use OpenDNS server to avoid DNS forward loop
		nameserver_ip=208.67.222.222

		config_dnsmasq $machine_ip $nameserver_ip
		launch_dnsmasq
		apply_dns_config $nameserver_ip

		launch_traefik

		config_concourse
		launch_concourse

		config_registry
		launch_registry

		config_fly
		gen_ssh_fly
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
