#!/bin/bash

### config ###

user_home=/home/user
log_dir=$user_home/restic_logs
script_dir=`cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P`
tiers="1"
backup_dirs_1="/mnt/data/media $user_home /mnt/data2 /var/lib/docker/volumes /home/borg/matrix"
# backup_dirs_2=""
creds_1="$script_dir/creds.sh"
# creds_2="$script_dir/creds-yandex.sh"
bot_token="" # Tg bot token
chat_id= # Tg user id
backup_name=`date +%Y%m%d_%H%M`
serv_dir=$user_home/server-config/self-hosted-docker
excluded_composes=(
  "$user_home/efprojects.com/docker-compose.yml"
  "$serv_dir/caddy/docker-compose.yml"
)
verify=$(expr "$1" != "skip_verify" )

### utils ###

sendTelega() {
  curl -sS --get --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$1" "https://api.telegram.org/bot$bot_token/sendMessage"
}

listComposes() {
  for c in `docker ps -q`; do
    docker inspect $c --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}/{{index .Config.Labels "com.docker.compose.project.config_files"}}'
  done
  # Костыль для случаев, когда до бекапа контейнеры не были запущены, но они всё равно нужны
  echo $serv_dir/navidrome/docker-compose.yml
  echo $serv_dir/nextcloud/docker-compose.yml
  echo $serv_dir/qbittorrent/docker-compose.yml
  echo $serv_dir/yourls/docker-compose.yml
  echo $serv_dir/gitea/docker-compose.yml
  echo $serv_dir/joplin/docker-compose.yml
  echo $serv_dir/paperless/docker-compose.yml
}

### backup ###

composes=$(listComposes | sort | uniq)
for comp in $composes; do
  if [[ ${excluded_composes[@]} =~ $comp ]] ; then
    continue
  fi
  cd $(dirname $comp) || continue
  echo "Stopping $comp"
  docker-compose -f $(basename $comp) stop
done

success=""
failed=""

for tier in $tiers; do
  backup_dirs=backup_dirs_$tier
  creds_file=creds_$tier
  source ${!creds_file}
  for backup_dir in ${!backup_dirs}; do
    echo "Backupping $backup_dir"
    if restic -v backup $backup_dir >> $log_dir/$backup_name.log 2>>$log_dir/$backup_name.err.log ; then
      echo Backup successful: $backup_dir
      success="$success $backup_dir"
    else
      echo Backup failed: $backup_dir
      failed="$failed $backup_dir"
    fi
  done
done

for comp in $composes; do
  if [[ ${excluded_composes[@]} =~ $comp ]] ; then
    continue
  fi
  cd $(dirname $comp) || continue
  echo "Starting $comp"
  docker-compose -f $(basename $comp) start
done
docker restart caddy_caddy_1

if [[ -n $success ]] ; then
  sendTelega "✅ Backup successful: `echo $success | wc -w`"
fi
if [[ -n $failed ]] ; then
  sendTelega "❌ Backup failed: `echo $failed | wc -w`"
  sendTelega "❌ `head -c 100 $log_dir/$backup_name.err.log`"
fi

if (( $verify == 0 )); then
  echo "Skipping verification"
  exit 0
fi

for tier in $tiers; do
  creds_file=creds_$tier
  source ${!creds_file}
  if restic check --read-data-subset=500M >> $log_dir/$backup_name.log 2>>$log_dir/$backup_name.err.log; then
    sendTelega "✅ Backup tier $tier integrity check OK"
  else
    sendTelega "❌ Backup tier $tier integrity check failed"
  fi
done
