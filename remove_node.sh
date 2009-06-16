#!/bin/bash

SELF="./script/ec2_runner/add_node.sh"
source "$(dirname $SELF)/shared.sh"
source "$(dirname $SELF)/functions.sh"


shutdown_iptables_tunnel() {
	local ip=${1:?shutdown_iptables_tunnel was not given an argument} from_port to_port to_ip number STARTING_PORTS_DIFFERENCE=$[$STARTING_LOCAL_BACKUP_PORT - $STARTING_LOCAL_PORT]
	for ip_and_ports in $($IPTABLES -t nat -L OUTPUT -n -v | grep :$ip: | sed "s/^.*:\([0-9]*\)\s*to:\(.*\)/\1:\2/"); do
		from_port=$(echo $ip_and_ports|cut -d: -f1)
		to_ip=$(echo $ip_and_ports|cut -d: -f2)
		to_port=$(echo $ip_and_ports|cut -d: -f3)
		
		number=$[from_port - $STARTING_LOCAL_PORT]
		[ $number -gt $STARTING_PORTS_DIFFERENCE ] && continue
		
		einfo "got infos: $from_port $to_ip $to_port -- $number shutting it down"
		$IPTABLES_TUNNEL remove $number $to_ip:$to_port &
	done
	
	wait
}


terminate_instance() {
	local instance=${1:?terminate_instance not given an arg, expecting an instance id}
	$EC2_PATH/ec2-terminate-instances $instance
}


remove_instance() {
	local instance instance_ip instance_hostname instance_id
	
	instance=$(get_instance_status ${1:-INSTANCE} | head -1)
	instance_id=$(echo $instance | awk '{ print $2 }')
	instance_hostname=$(echo $instance | awk '{ print $4 }')
	instance_ip=$(lookup_host $instance_hostname)
	
	einfo "removing ec2 instance $instance_id ( at $instance_ip )"
	
	shutdown_iptables_tunnel $instance_ip
	
	einfo "done, now shutting down the instance ($instance_id)"
	terminate_instance $instance_id
}


remove_instance