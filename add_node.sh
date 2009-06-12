#!/bin/bash

source functions.sh


export EC2_HOME=/usr/local/ec2-api-tools
export EC2_PATH=/usr/local/ec2-api-tools/bin

export EC2_CERT=$(echo ~/.ec2/cert-*.pem)
export EC2_PRIVATE_KEY=$(echo ~/.ec2/pk-*.pem)

IPTABLES_TUNNEL="./script/iptables_tunnel/iptables_tunnel.sh"

STARTING_LOCAL_PORT=5000
STARTING_LOCAL_BACKUP_PORT=5500
STARTING_REMOTE_PORT=3500
N_LOCAL_PORTS=29
PORTS_PER_EC2=5

# ec2_image=ami-7767811e
# or
ec2_image_location='tatango-amis/almost_ready.manifest.xml'

check_rails() {
	[ -x script/about ] || exit_with_error 10 "please run this script in the root directory of a rails project"
}

check_root() {
	[ $(whoami) = 'root' ] || exit_with_error 10 "please run this script as root"
}

determine_my_ip() {
	ifconfig eth0 | grep inet | grep -v inet6 | cut -d ":" -f 2 | cut -d " " -f 1
}

lookup_host() {
	local name=${1:?no arg given in lookup_host}
	host -t A $name | head -1 | awk '{ print $NF }'
}

lookup_image() {
	local location=${1:?no arg given in lookup_image}
	$EC2_PATH/ec2-describe-images | grep $location | awk '{ print $2 }'
}

start_instance() {
	local image=${1:?no arg given to start_instance, expecting an image (ami-*)}
	$EC2_PATH/ec2-run-instances $image | grep INSTANCE | awk '{ print $2 }'
}


get_state() {
	local instance=${1:?no arg given to get_state, expecting an instance (i-*)}
	$EC2_PATH/ec2-describe-instances | grep $instance
}


find_first_available_port() {
	local my_ip=${1:?my_ip not supplied to find_first_available_port}
	for i in $(seq 0 $N_LOCAL_PORTS); do
		nc -z $my_ip $[i+$STARTING_LOCAL_PORT] || { echo $[i+$STARTING_LOCAL_PORT]; break }
	done
}

start_setup_and_deploy() {
	local instance hostname ip my_ip=$(determine_my_ip)
	
	[ -z $my_ip ] && eerror 2 'could not determine my ip address'
	
	if [ -z $ec2_image ]; then
		ebegin "determining image id for $ec2_image_location"
		ec2_image=$(lookup_image $ec2_image_location)
		eend $(test ! -z $ec2_image; echo $?)
	fi
	
	[ -z $ec2_image ] && exit_with_error 2 'no ec2 image id given or found'
	
	# start the instance
	
	ebegin "starting $ec2_image"
	instance=$(start_instance $ec2_image)
	eend $(test ! -z $instance; echo $?)
	einfo "instance is $instance"
	
	# wait for it to boot
	
	ebegin "waiting for instance to boot up"
	while get_state $instance | grep -q pending; do
		sleep 5
	done
	eend 0
	
	# get its ip
	
	hostname=$(get_state $instance | awk '{ print $4 }')
	einfo "got instance hostname: $hostname"
	
	ip=$(lookup_host $hostname)
	einfo "got ip: $ip"
	
	# TODO: setup tunnel here
	
	# deploy
	
	cap HOSTS="$ip" deploy

	
	# setup iptables_tunnel
	local first_port port_base_number remote_port

	first_port=$(find_first_available_port $my_ip)
	
	for i in $(seq 0 $PORTS_PER_EC2); do
		# local_ports[$i]=$[i+$first_port]
		port_base_number=$[first_port + i - $STARTING_LOCAL_PORT]
		remote_port=$[i + $STARTING_REMOTE_PORT]
		$IPTABLES_TUNNEL add $port_base_number $ip:$remote_port
	done
		
}

check_rails
check_root
start_setup_and_deploy