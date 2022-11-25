#!/bin/bash

sleep 30
touch /etc/profile.d/load_env.sh

{
    echo "export PLAYBACK_BASE_URL=\"${reporter_url}\""
    echo "export UPLOADER_PATH=\"${media_output_dir}${media_file_ready_dir}\""  
    echo "export PLAYSVC_LISTEN_PORT=\"${playsvc_listen_port}\""

    echo "export EFS=\"${efs_dns_name}\""
    echo "export MEDIA_DIR=\"${media_output_dir}\""
    echo "export MEDIA_MIXER_DIR=\"${media_mixer_dir}\""
    echo "export MEDIA_FILE_READY_DIR=\"${media_file_ready_dir}\""
    echo "export MIXER_OUTDIR=\"${media_output_dir}${media_mixer_dir}\""

    echo "export SERVICE_LOG_FILE_PATH=\"${service_log_file_path}\""
    echo "export LOG_GROUP_NAME=\"${log_group_name}\""
    echo "export LOG_STREAM_NAME=\"${log_stream_name}\""
} >> /etc/profile.d/load_env.sh




chmod 440 /etc/profile.d/load_env.sh
sudo chown ubuntu:ubuntu /etc/profile.d/load_env.sh
set -a; source /etc/profile.d/load_env.sh; set +a


echo "Render Playsvc config file"
sudo systemctl stop playsvc.service
envsubst '$PLAYBACK_BASE_URL,$UPLOADER_PATH,$PLAYSVC_LISTEN_PORT' < /playsvc/config_template.json | sudo tee /playsvc/config.json


echo "Render Cloudwatch Config file and start service"
envsubst '$SERVICE_LOG_FILE_PATH,$LOG_GROUP_NAME,$LOG_STREAM_NAME' < /home/ubuntu/cloudwatch/cloudwatch_config_template.json | sudo tee /home/ubuntu/cloudwatch/config.json
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/home/ubuntu/cloudwatch/config.json -s
rm /home/ubuntu/cloudwatch/cloudwatch_config_template.json


echo "Mounting EFS volume"
sudo mkdir -p "$MEDIA_DIR"
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS":/ "$MEDIA_DIR"
sudo mkdir -p "$MEDIA_DIR""$MEDIA_MIXER_DIR"
sudo mkdir -p "$MEDIA_DIR""$MEDIA_FILE_READY_DIR"
sudo chmod 777 "$MEDIA_DIR"
sudo su -c "echo \"$EFS\":/ \"$MEDIA_DIR\" nfs4 defaults,_netdev 0 0 >> /etc/fstab"

echo "Launching Playsvc..."
sudo systemctl start playsvc.service
