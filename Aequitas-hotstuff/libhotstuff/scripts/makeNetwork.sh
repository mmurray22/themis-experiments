#!/bin/bash
## Created By: Suyash Gupta - 08/23/2023. Edited Micah - 02/12/2024
##
## This script helps to create the files that specify URLs for RSM1 and RSM2. Additionally, it calls the script that helps to create "config.h". We need to specify the URLs and stakes for each node in both the RSMs. This script takes in argument the size of both the RSMs and other necessary parameters.

if [ -z ${TMUX+x} ]; then
	echo "Run script in tmux to guarantee progress"
	echo "exiting..."
	exit 1
fi

# Name of profile we are running out of
key_file="$HOME/.ssh/id_ed25519" # TODO: Replace with your ssh key
username="scrooge"               # TODO: Replace with your username

# TODO Change to inputs!!
GP_NAME="testing-themis"
NUM_NODES=21 # f = 5
ZONE="us-central1-a"
TEMPLATE="dumb"
IP_FILE_PATH="/home/micahrocks/themis-experiments/Aequitas-hotstuff/libhotstuff/scripts/deploy"

function exit_handler() {
    echo "** Trapped CTRL-C, deleting experiment"
	yes | gcloud compute instance-groups managed delete $GP_NAME --zone $ZONE
	exit 1
}

trap exit_handler INT
echo "CREATE: ${GP_NAME} with $((NUM_NODES+2)) in ${ZONE} with template ${TEMPLATE}"
yes | gcloud beta compute instance-groups managed create "${GP_NAME}" --project=fair-ordering-as-a-service --base-instance-name="${GP_NAME}" --size="$((NUM_NODES+2))" --template=projects/fair-ordering-as-a-service/global/instanceTemplates/${TEMPLATE} --zone="${ZONE}" --list-managed-instances-results=PAGELESS --stateful-internal-ip=interface-name=nic0,auto-delete=never --no-force-update-on-repair 
#> /dev/null 2>&1

# Remove prior files and initialize necessary variables
rm /tmp/all_ips.txt
rm "${IP_FILE_PATH}"/ips.txt
rm "${IP_FILE_PATH}"/replicas.txt
rm "${IP_FILE_PATH}"/clients.txt
replicas=()
clients=()

echo "Enumerating IPs in intermediate file"
# Enumerate IPs in intermediate file
num_ips_read=0
while ((${num_ips_read} < $((NUM_NODES+2)))); do
	gcloud compute instances list --filter="name~^${GP_NAME}" --format='value(networkInterfaces[0].networkIP)' > /tmp/all_ips.txt
	output=$(cat /tmp/all_ips.txt)
	ar=($output)
	num_ips_read="${#ar[@]}"
    echo "Intermediate: ${num_ips_read}"
done

# Separate replica and client IPs
replicas=(${ar[@]::${NUM_NODES}})
clients=(${ar[@]:${NUM_NODES}:2})

echo "Starting to create replica and client files!"

# Add to replicas file
count=0
while ((${count} < ${NUM_NODES})); do
    echo "Replicas: ${replicas[$count]}"
    echo "${replicas[$count]} ${replicas[$count]}" >> "${IP_FILE_PATH}"/replicas.txt
	count=$((count + 1))
	if [ ${count} -eq "${NUM_NODES}" ]; then
		break
	fi
done

echo "Done making replicas file!"

# Add to clients file
count=0
while ((${count} < 2)); do
	echo "Client: ${clients[$count]}"
    echo ${clients[$count]} >> "${IP_FILE_PATH}"/clients.txt
	count=$((count + 1))
	if [ ${count} -eq 2 ]; then
		break
	fi
done

echo "Done making client file!"
#sleep 600

#yes | gcloud compute instance-groups managed delete $GP_NAME --zone $ZONE
