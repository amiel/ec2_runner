#!/bin/bash

SELF="./script/ec2_runner/add_node.sh"
source "$(dirname $SELF)/shared.sh"
source "$(dirname $SELF)/functions.sh"



get_instance() {
	
}



remove_instance() {
	local instance
	
	instance=$(get_instance $1)
}


remove_instance