#!/bin/bash

sleep 30
touch /etc/profile.d/load_env.sh
EXTERNAL_IP=`dig +short myip.opendns.com @resolver1.opendns.com`
{
    echo "export KURENTO_SERVICE_LOG_FILE_PATH=\"${kurento_service_log_file_path}\""
    echo "export KURENTO_LOG_GROUP_NAME=\"${kurento_log_group_name}\""
    echo "export KURENTO_LOG_STREAM_NAME=\"${kurento_log_stream_name}\""
    echo "export COTURN_SERVICE_LOG_FILE_PATH=\"${coturn_service_log_file_path}\""
    echo "export COTURN_LOG_GROUP_NAME=\"${coturn_log_group_name}\""
    echo "export COTURN_LOG_STREAM_NAME=\"${coturn_log_stream_name}\""
    echo "export LOG_NAME=\"${log_name}\""


    echo "export COTURN_LISTENER_PORT=\"${coturn_listener_port}\""
    echo "export COTURN_ALT_LISTENER_PORT=\"${coturn_alt_listener_port}\""

    echo "export KURENTO_HOST_IP=\"${kurento_host_ip}\""
    
    echo "export EXTERNAL_IP=\"$EXTERNAL_IP\""
    echo "export INTERNAL_IP=\"${internal_ip}\""
    echo "export TURN_SERVER_USERNAME=\"${turn_server_username}\""
    echo "export TURN_SERVER_PASSWORD=\"${turn_server_password}\""
    echo "export TURN_SERVER_MIN_PORT=\"${turn_server_min_port}\""
    echo "export TURN_SERVER_MAX_PORT=\"${turn_server_max_port}\""

    echo "export AWS_MONITORING_ACCESS_KEY=\"${kurento_aws_monitoring_access_key}\""
    echo "export AWS_MONITORING_SECRET_KEY=\"${kurento_aws_monitoring_secret_key}\""
    echo "export REGION=\"${aws_region}\""
    echo "export STATS_NAMESPACE=\"${kurento_stats_namespace}\""
    echo "export INSTANCE_NAME=\"${instance_name}\""

    echo "export EFS=\"${efs_dns_name}\""
    echo "export MEDIA_DIR=\"${media_output_dir}\""
} >> /etc/profile.d/load_env.sh




chmod 440 /etc/profile.d/load_env.sh
sudo chown ubuntu:ubuntu /etc/profile.d/load_env.sh
set -a; source /etc/profile.d/load_env.sh; set +a

echo "Render turnserver config file"
envsubst '$COTURN_LISTENER_PORT,$COTURN_ALT_LISTENER_PORT,$EXTERNAL_IP,$INTERNAL_IP,$TURN_SERVER_USERNAME,$TURN_SERVER_PASSWORD,$TURN_SERVER_MIN_PORT,$TURN_SERVER_MAX_PORT' < /home/ubuntu/turnserver-template.conf | sudo tee /etc/turnserver.conf
envsubst '$COTURN_LISTENER_PORT,$EXTERNAL_IP,$TURN_SERVER_USERNAME,$TURN_SERVER_PASSWORD' < /home/ubuntu/launch-kms-tempate.sh | sudo tee /usr/local/bin/launch-kms.sh
sudo touch /var/log/turnserver/turnserver.log
sudo chmod 777 /var/log/turnserver/turnserver.log

echo "turnURL=$TURN_SERVER_USERNAME:$TURN_SERVER_PASSWORD@$EXTERNAL_IP:$COTURN_LISTENER_PORT" > /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
echo "externalIPv4=$EXTERNAL_IP" >> /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
echo "iceTcp=0" >> /etc/kurento/modules/kurento/WebRtcEndpoint.conf.ini
echo "minPort=$TURN_SERVER_MIN_PORT" >> /etc/kurento/modules/kurento/BaseRtpEndpoint.conf.ini
echo "maxPort=$TURN_SERVER_MAX_PORT" >> /etc/kurento/modules/kurento/BaseRtpEndpoint.conf.ini



echo "Render Kurento Stats Config file and start Service"
envsubst '$AWS_MONITORING_ACCESS_KEY,$AWS_MONITORING_SECRET_KEY,$REGION,$STATS_NAMESPACE,$INSTANCE_NAME' < /home/ubuntu/kurentostats-template.conf | sudo tee /opt/kmon/kurentostats.conf
sudo systemctl daemon-reload
sudo systemctl start kurento-stats.service
sudo systemctl start kurento-stats.timer


echo "Render Cloudwatch Config file and start service"
envsubst '$KURENTO_SERVICE_LOG_FILE_PATH,$KURENTO_LOG_GROUP_NAME,$KURENTO_LOG_STREAM_NAME,$COTURN_SERVICE_LOG_FILE_PATH,$COTURN_LOG_GROUP_NAME,$COTURN_LOG_STREAM_NAME,$LOG_NAME' < /home/ubuntu/cloudwatch/cloudwatch_config_template.json | tee /home/ubuntu/cloudwatch/config.json
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/home/ubuntu/cloudwatch/config.json -s
# rm /home/ubuntu/cloudwatch/cloudwatch_config_template.json


echo "Mounting EFS volume"
sudo mkdir -p "$MEDIA_DIR"
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS":/ "$MEDIA_DIR"
sudo chmod 777 "$MEDIA_DIR"
sudo su -c "echo \"$EFS\":/ \"$MEDIA_DIR\" nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0 >> /etc/fstab"

echo "Launching Media Server..."
sudo systemctl stop kms
sudo systemctl stop coturn
sudo systemctl start kms
sudo systemctl start coturn
