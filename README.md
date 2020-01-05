# Backup Scripts

Some handy backup scripts I wrote. No warranty for this scripts!

## Docker Volumes

This script backups all docker volumes to .tar files and delete older files. It is basically based on the [offical best practice](https://docs.docker.com/storage/volumes/#backup-a-container). However, instead of doing a manually backup for each volume, this script automatically backups all volumes from running containers.

Always do a dry run. Some volumes can not be backuped (e.g. `/var/run/docker.sock`).

### Requirements

Busybox Docker image: `docker pull busybox`.

### Usage

To get more info on usage:

`backup_all_docker_volumes.sh -h`
