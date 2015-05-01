#!/usr/bin/env bash
 
shopt -s nullglob
 
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id);
DATE_STAMP=$(date --utc --iso-8601=s | sed 's/[:+]/_/g');
TMP=$(mktemp -d --tmpdir='/tmp/'  instance-id-${DATE_STAMP}-${INSTANCE_ID}.XXXXXXXXXX) && {
    docker info > "${TMP}/docker-info"
 
    netstat -ntlp > "${TMP}/netstat"
 
    DOCKER_GRAPH_PATH=$(docker info | awk -F':' '/Data loop file/ {print $2}' | sed 's/devicemapper\/devicemapper\/data//g');
    docker ps -a > "${TMP}/docker-ps-a"
    docker ps -a | egrep -v '^CONTAINER ID' | while read line; do 
        CID=$(echo $line | awk '{print $1}');
        mkdir -p "${TMP}/containers/${CID}/logs"
        docker inspect $CID > "${TMP}/containers/$CID/docker-inspect"
        CID_LONG=$(cat "${TMP}/containers/$CID/docker-inspect" | awk -F '"' '/Id/ {print $4}')
 
        # Avoid empty
        log_files=("$DOCKER_GRAPH_PATH/containers/*-json.log");
        for f in $log_files; do
            cp -fv $f "${TMP}/containers/$CID/logs"
        done
    done;
    iptables-save > "${TMP}/iptables";
    
    mkdir -p "${TMP}/var/log" "${TMP}/ecs";
    /opt/aws/bin/ec2-metadata > "${TMP}/ec2-metadata"
    
    curl -s 127.0.0.1:51678/v1/metadata | python -mjson.tool > "${TMP}/ecs/metadata";
    curl -s 127.0.0.1:51678/v1/tasks | python -mjson.tool > "${TMP}/ecs/tasks";
    
    cp -Rv /var/log/ecs /var/log/syslog* /var/log/dmesg* /var/log/kern.log* "${TMP}/var/log"
    
    tar -zcvf "${TMP}.tar.gz" "${TMP}"
    echo "Create '${TMP}.tar.gz'"
}
