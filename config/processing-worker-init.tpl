#!/bin/bash

sleep 30
touch /etc/profile.d/load_env.sh

{
    echo "export EFS=\"${efs_dns_name}\""
    echo "export OUTPUT_EFS=\"${output_efs_dns_name}\""
    echo "export MEDIA_DIR=\"${media_input_dir}\""
    echo "export MEDIA_OUTPUT_DIR=\"${media_output_dir}\""
    echo "export MEDIA_MIXER_DIR=\"${media_mixer_dir}\""
    echo "export MEDIA_FILE_READY_DIR=\"${media_file_ready_dir}\""

    echo "export RECSVC_LISTEN_PORT=\"${recsvc_listen_port}\""
    echo "export MIXER_TOOL=\"${mixer_tool}\""

    echo "export MIXER_OUTDIR=\"/tmp\""
    echo "export UPLOADER_PATH=\"${media_output_dir}${media_file_ready_dir}\""
    # echo "export MIXER_OUTDIR=\"$MEDIA_DIR$MEDIA_MIXER_DIR\"" >> /etc/profile.d/load_env.sh
    # echo "export UPLOADER_PATH=\"$MEDIA_DIR$MEDIA_FILE_READY_DIR\"" >> /etc/profile.d/load_env.sh
    echo "export GENESYS_WEBDAB_SERVER_URL=\"${genesys_webdav_server_url}\""
    echo "export GENESYS_USERNAME=\"${genesys_username}\""
    echo "export GENESYS_PASSWORD=\"${genesys_password}\""
    echo "export REPORTER_URL=\"${reporter_url}\""


    echo "export SERVICE_LOG_FILE_PATH=\"${service_log_file_path}\""
    echo "export LOG_GROUP_NAME=\"${log_group_name}\""
    echo "export LOG_STREAM_NAME=\"${log_stream_name}\""

    echo "export USE_ARCHIVER=\"${use_archiver}\""
    echo "export ARCHIVER_LISTEN_PORT=\"${archiver_listen_port}\""
    echo "export ARCHIVER_BASE_PATH=\"${media_output_dir}\""
    echo "export ARCHIVER_LOG_STREAM_NAME=\"${archiver_log_stream_name}\""
    echo "export ARCHIVER_SERVICE_LOG_FILE_PATH=\"${archiver_log_file_path}\""
    echo "export ARCHIVER_BASE_URL=\"${archiver_base_url}\""

    echo "export USE_VERINT_CONNECTOR=\"${use_verint_connector}\""
    echo "export LISTEN_PORT=\"${verint_connector_listen_port}\""
    echo "export BASE_PATH=\"${media_output_dir}${media_file_ready_dir}\""
    echo "export VERINT_CONNECTOR_LOG_STREAM_NAME=\"${verint_connector_log_stream_name}\""
    echo "export VERINT_CONNECTOR_LOG_FILE_PATH=\"${verint_connector_log_file_path}\""
    echo "export BASE_URL=\"${verint_connector_base_url}\""

} >> /etc/profile.d/load_env.sh




chmod 440 /etc/profile.d/load_env.sh
sudo chown ubuntu:ubuntu /etc/profile.d/load_env.sh
set -a; source /etc/profile.d/load_env.sh; set +a


echo "Render Recsvc config file"
sudo systemctl stop recsvc.service
envsubst '$RECSVC_LISTEN_PORT,$MIXER_TOOL,$MIXER_OUTDIR,$UPLOADER_PATH,$GENESYS_WEBDAB_SERVER_URL,$GENESYS_USERNAME,$GENESYS_PASSWORD,$REPORTER_URL' < /recsvc/config_template.json | sudo tee /recsvc/config.json

echo "Render Archivesvc config file"
sudo rm -f /archivesvc/config.json
sudo systemctl stop archivesvc.service
envsubst '$ARCHIVER_LISTEN_PORT,$ARCHIVER_BASE_PATH,$ARCHIVER_BASE_URL' < /archivesvc/config_template.json | sudo tee /archivesvc/config.json

echo "Render Verint connector config file"
sudo rm -f /verintconnsvc/config.json
sudo systemctl stop verintconnsvc.service
envsubst '$LISTEN_PORT,$BASE_PATH,$BASE_URL,$MIXER_TOOL' < /verintconnsvc/config_template.json | sudo tee /verintconnsvc/config.json


echo "Render Cloudwatch Config file and start service"
envsubst '$SERVICE_LOG_FILE_PATH,$LOG_GROUP_NAME,$LOG_STREAM_NAME,$ARCHIVER_LOG_STREAM_NAME,$ARCHIVER_SERVICE_LOG_FILE_PATH,$VERINT_CONNECTOR_LOG_STREAM_NAME,$VERINT_CONNECTOR_LOG_FILE_PATH' < /home/ubuntu/cloudwatch/cloudwatch_config_template.json | sudo tee /home/ubuntu/cloudwatch/config.json
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/home/ubuntu/cloudwatch/config.json -s
rm /home/ubuntu/cloudwatch/cloudwatch_config_template.json


echo "Mounting EFS volume"
sudo mkdir -p "$MEDIA_DIR"
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS":/ "$MEDIA_DIR"
sudo mkdir -p "$MEDIA_DIR""$MEDIA_MIXER_DIR"
sudo mkdir -p "$MEDIA_DIR""$MEDIA_FILE_READY_DIR"
sudo chmod 777 "$MEDIA_DIR"
sudo su -c "echo \"$EFS\":/ \"$MEDIA_DIR\" nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0 >> /etc/fstab"
if [ "$MEDIA_DIR" != "$MEDIA_OUTPUT_DIR" ] && [ "$EFS" != "$OUTPUT_EFS" ]; then
    sudo mkdir -p "$MEDIA_OUTPUT_DIR"
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$OUTPUT_EFS":/ "$MEDIA_OUTPUT_DIR"
    sudo mkdir -p "$MEDIA_OUTPUT_DIR""$MEDIA_FILE_READY_DIR"
    sudo chmod 777 "$MEDIA_OUTPUT_DIR"
    sudo su -c "echo \"$OUTPUT_EFS\":/ \"$MEDIA_OUTPUT_DIR\" nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0 >> /etc/fstab"
fi

echo "Launching Recsvc..."
sudo systemctl start recsvc.service

if [ "$USE_ARCHIVER" == "true" ]; then
    echo "Launching Archivesvc..."
    sudo systemctl start archivesvc.service
fi

if [ "$USE_VERINT_CONNECTOR" == "true" ]; then
    echo "Launching Verint connector service..."
    sudo systemctl start verintconnsvc.service
fi
