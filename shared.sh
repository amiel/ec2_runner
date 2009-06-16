


export EC2_HOME=/usr/local/ec2-api-tools
export EC2_PATH=/usr/local/ec2-api-tools/bin

export EC2_CERT=$(echo ~/.ec2/cert-*.pem)
export EC2_PRIVATE_KEY=$(echo ~/.ec2/pk-*.pem)


IPTABLES=/sbin/iptables
IPTABLES_TUNNEL="$(dirname $SELF)/iptables_tunnel.sh"

# STARTING_LOCAL_PORT should be less than STARTING_LOCAL_BACKUP_PORT
STARTING_LOCAL_PORT=5000
STARTING_LOCAL_BACKUP_PORT=5500
STARTING_REMOTE_PORT=3500
N_LOCAL_PORTS=29
PORTS_PER_EC2=5




exit_with_error() {
	local error_num=$1
	shift
	eerror $*
	exit $error_num
}


check_rails() {
	[ -x script/about ] || exit_with_error 10 "please run this script in the root directory of a rails project"
}

check_root() {
	[ $(whoami) = 'root' ] || exit_with_error 10 "please run this script as root"
}


lookup_host() {
	local name=${1:?no arg given in lookup_host}
	host -t A $name | head -1 | awk '{ print $NF }'
}

get_instance_status() {
	local instance=${1:?no arg given to get_instance_status, expecting an instance (i-*)}
	$EC2_PATH/ec2-describe-instances | grep $instance
}