#!/bin/bash

sleep 30

#prevent lambda rebooting during setup
echo "HandlePowerKey=ignore" >> /etc/systemd/logind.conf
systemctl restart systemd-logind

yum updateinfo -y
yum install bind-utils -y

EXTERNAL_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

echo "$(date) Install docker and docker-compose"
curl -fsSL https://get.docker.com/ | sh
systemctl start docker
systemctl status docker
systemctl enable docker
usermod -aG docker $(whoami)
curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "$(date) Mounting EFS volume"
mkdir -p ${media_output_dir}
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ ${media_output_dir}

echo "${efs_dns_name}:/ ${media_output_dir} nfs4 defaults,_netdev 0 0" >> /etc/fstab
mkdir ${media_output_dir}/outdir
mkdir ${media_output_dir}/s3
chmod 777 -R ${media_output_dir}

echo "$(date) Generating docker-compose"
tee -a /tmp/docker-compose.yml << END
version: '3'

services:
  kurento_worker:
    image: 376474804475.dkr.ecr.eu-west-1.amazonaws.com/recording-kurento:latest
    environment:
      - TURN_URL=${turn_server_username}:${turn_server_password}@$EXTERNAL_IP:${coturn_listener_port}
    ports:
       - '8888:8888'
    restart: always
    tty: true
    container_name: kurento_worker
    volumes:
       - ${log_dir}/:/var/log/kurento-media-server/
       - ${media_output_dir}/:/rec

  play:
    image: 376474804475.dkr.ecr.eu-west-1.amazonaws.com/recording-play:latest
    environment: 
      - PLAYBACK_BASE_URL=${playback_base_url}
      - PLAYSVC_LISTEN_PORT=${play_listener_port}
    restart: always
    tty: true
    container_name: play_worker
    ports:
      - ${play_listener_port}:${play_listener_port}
    volumes:
       - ${log_dir}/:/playsvc/log/
       - ${media_output_dir}/:/rec


  processing_worker:
    image: 376474804475.dkr.ecr.eu-west-1.amazonaws.com/recording-processing:latest
    environment: 
      - PLAYBACK_BASE_URL=https://videome.leadsecure.com
    restart: always
    tty: true
    container_name: processing_worker
    ports:
      - 7002:7002
    volumes:
       - ${log_dir}/:/recsvc/log/
       - ${log_dir}/:/var/log/supervisor/
       - ${media_output_dir}/:/rec


  coturn:
    image: 376474804475.dkr.ecr.eu-west-1.amazonaws.com/recording-turn:latest
    environment: 
      - PUBLIC_IP=$EXTERNAL_IP
      - PRIVATE_IP=${internal_ip}
      - TURN_USER=${turn_server_username}
      - TURN_PASSWORD=${turn_server_password}
      - IS_TURN_ON_AWS=true
    tty: true
    restart: always
    container_name: coturn
    network_mode: "host"
    volumes:
       - ${log_dir}/:/var/log/turnserver/
END

echo "$(date) docker-compose login"
docker login -u AWS 376474804475.dkr.ecr.eu-west-1.amazonaws.com -p ${docker_token}

echo "$(date) docker-compose up"
docker-compose -f /tmp/docker-compose.yml up -d

#restore power button actions
sed -i '/HandlePowerKey=ignore/d' /etc/systemd/logind.conf
systemctl restart systemd-logind

echo "$(date) Done!"

