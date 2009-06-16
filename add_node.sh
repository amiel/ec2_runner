#!/bin/bash

SELF="./script/ec2_runner/add_node.sh"
source "$(dirname $SELF)/shared.sh"
source "$(dirname $SELF)/functions.sh"


# ec2_image=ami-
# or
ec2_image_location='tatango-amis/should_work.manifest.xml'


determine_my_ip() {
	ifconfig eth0 | grep inet | grep -v inet6 | cut -d ":" -f 2 | cut -d " " -f 1
}



lookup_image() {
	local location=${1:?no arg given in lookup_image}
	$EC2_PATH/ec2-describe-images | grep $location | awk '{ print $2 }'
}

start_instance() {
	local image=${1:?no arg given to start_instance, expecting an image (ami-*)}
	$EC2_PATH/ec2-run-instances $image | grep INSTANCE | awk '{ print $2 }'
}




find_first_available_port() {
	# local my_ip=${1:?my_ip not supplied to find_first_available_port}
	for i in $(seq 0 $N_LOCAL_PORTS); do
		# nc -z $my_ip $[i+$STARTING_LOCAL_PORT] > /dev/null || { echo $[i+$STARTING_LOCAL_PORT]; break; }
		$IPTABLES -L OUTPUT -t nat -v -n | grep -q $[i+$STARTING_LOCAL_PORT] || { echo $[i+$STARTING_LOCAL_PORT]; break; }
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
	while get_instance_status $instance | grep -q pending; do
		sleep 5
	done
	eend 0
	
	# get its ip
	
	hostname=$(get_instance_status $instance | awk '{ print $4 }')
	einfo "got instance hostname: $hostname"
	
	ip=$(lookup_host $hostname)
	einfo "got ip: $ip"
	
	# NOTE: tunnel for mysql stuffs should be setup by the instance itself
	
	# deploy
	
	cap HOSTS="$ip" deploy


	einfo "deployed, now setting up iptables tunnels"
	
	# setup iptables_tunnel
	local first_port port_base_number remote_port

	first_port=$(find_first_available_port $my_ip)
	
	for i in $(seq 0 $[PORTS_PER_EC2 - 1]); do
		# local_ports[$i]=$[i+$first_port]
		port_base_number=$[first_port + i - $STARTING_LOCAL_PORT]
		remote_port=$[i + $STARTING_REMOTE_PORT]
		# background this bitch, not that the backgrounding will be more important when we are shutting down
		$IPTABLES_TUNNEL add $port_base_number $ip:$remote_port &
	done

	wait
}


check_rails
check_root

start_setup_and_deploy