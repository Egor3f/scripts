#!/usr/bin/env zsh

set -e

CACHE_DIR=/tmp/rclone_cache_nc
MOUNT_DIR=/Users/egor/Nextcloud
LOG_FILE=/var/log/rclone/nc.txt
LOGROTATE_CONF=/tmp/logrotate.conf

if pgrep rclone; then
  echo rclone is already running
  exit 1
fi

rm -rf $MOUNT_DIR/.DS_Store

rm -rf $CACHE_DIR

touch $LOG_FILE
cat > /tmp/logrotate.conf <<EOF
$LOG_FILE {
  rotate 4
  weekly
}
EOF
logrotate $LOGROTATE_CONF

rclone mount nextcloud:/ $MOUNT_DIR \
  --cache-dir $CACHE_DIR \
  --vfs-cache-mode full \
  --vfs-cache-max-size 1Gi \
  --vfs-cache-min-free-space 10Gi \
  --volname Nextcloud \
  --max-read-ahead 1Mi \
  --noapplexattr \
  --vfs-block-norm-dupes \
  --webdav-pacer-min-sleep 1ms \
  --disable-http2 \
  --log-file=$LOG_FILE \
  --log-level INFO \
  --daemon \
  && echo running rclone \
  || echo failed to run: code $?

tail $LOG_FILE
