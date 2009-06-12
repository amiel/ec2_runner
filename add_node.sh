#!/bin/bash

source functions.sh


export EC2_HOME=/usr/local/ec2-api-tools
export EC2_PATH=/usr/local/ec2-api-tools/bin

export EC2_CERT=$(echo ~/.ec2/cert-*.pem)
export EC2_PRIVATE_KEY=$(echo ~/.ec2/pk-*.pem)

# ec2_image=ami-7767811e
# or
ec2_image_location='tatango-amis/almost_ready.manifest.xml'

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


start_and_setup() {
	local instance hostname ip
	
	if [ -z $ec2_image -a ! -z $ec2_image_location ]; then
		ec2_image=$(lookup_image $ec2_image_location)
	fi
	
	# start the instance
	
	ebegin "starting $ec2_image"
	instance=$(start_instance $ec2_image)
	eend $?
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
	
	
	
}


start_and_setup