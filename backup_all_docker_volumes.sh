#!/bin/bash


# usage function
function usage()
{
   cat << HEREDOC

   Usage: backup_all_docker_volumes.sh [--dry-run] [-c <container>] [-v <volume>] -b <backupfolder> -d <days>

   arguments:
     -h, --help           show this help message and exit
     -c                   exclude containers with the following name (regex)
     -v                   exclude volumes with the following name (regex)
     -b                   backup location of the docker volumes
     -d                   delete all .tar files older than d in the backup folder
     --dry-run            do a dry run, dont change any files

   Backup all Docker volumes for containers which are currently running.
   The volumes will be attached readonly to an temporary busybox container
   which archives all contents in a .tar file in the backup folder.

   Additional it deletes older .tar files based on their creation date.

   The final folder structure of the backup folder will look like this:
        backupfolder
          | container1
          |    | volume1_date1.tar
          |    | volume1_date2.tar
          |    | ...
          |    | volume2_date1.tar
          |    | ...
          | container2
          |    | ...
          | ...

HEREDOC
exit 1
}

CONTAINER_REGEX="*"
VOLUME_REGEX="*"
BASEFOLDER=
DRYRUN=FALSE
DELETEDAYS=


while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --dry-run)
    DRYRUN=TRUE
    shift # past argument
    ;;
    -b)
    BASEFOLDER="$2"
    shift # past argument
    shift # past value
    ;;
    -d)
    DELETEDAYS="$2"
    shift # past argument
    shift # past value
    ;;
    -c)
    CONTAINER_REGEX="$2"
    shift # past argument
    shift # past value
    ;;
    -v)
    VOLUME_REGEX="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    usage
    shift # past argument
    ;;
esac
done

if [ ! -d "$BASEFOLDER" ]; then
  echo "Provided backup folder $BASEFOLDER does not exist!"
  exit 1
fi

if ! [[ "$DELETEDAYS" =~ ^[0-9]+$ ]]
then
    echo "Only integers valid for for delete days (-d argument)"
    exit 1
fi

# loop over all lines of output
docker container ls --format "{{.Names}};{{.Mounts}}" --no-trunc | while read LINE ; do

    CONTAINER=$(echo "$LINE" | cut -d';' -f1) # container name
    VOLUMES=$(echo "$LINE" | cut -d';' -f2) # comma separated list of volumes

    if [[ ! "$CONTAINER" =~ $CONTAINER_REGEX ]]
    then

    
        echo "[-] Container: $CONTAINER"

        # loop over all volumes
        for VOLUME in $(echo "$VOLUMES" | sed "s/,/ /g")
        do

            if [[ ! "$VOLUME" =~ $VOLUME_REGEX ]]
            then

                FOLDER="$BASEFOLDER"/"$CONTAINER"

                DATE=$(date +"%Y-%m-%d_%H-%M-%S")

                # replace "/" with underscores so that we don't get so many subfolders in Backup folder
                VOLUME_WITH_UNDERSCORE=${VOLUME//\//_}

                echo "[-]   Volume (Path or ID): $VOLUME"
                echo "[-]   Backup file: $FOLDER/$VOLUME_WITH_UNDERSCORE.$DATE.tar"

                if [[ $DRYRUN == "FALSE" ]]
                then
                    # create the folder
                    mkdir "$FOLDER" -p

                    # do the actual backup. Based on: https://docs.docker.com/storage/volumes/#backup-a-container
                    docker run --rm -v "$VOLUME":/volume:ro -v "$FOLDER":/backup busybox tar -czf /backup/"$VOLUME_WITH_UNDERSCORE"."$DATE".tar -C /volume .
                fi
            else
                echo "[X]   Volume $VOLUME excluded because of volume regex: $VOLUME_REGEX"
            fi
        done
    else
        echo "[X] Container $CONTAINER excluded because of container regex: $CONTAINER_REGEX"
    fi

    echo ""
done

# delete old folders
if [[ $DRYRUN == "FALSE" ]]
then
    find "$BASEFOLDER" -name "*.tar" -type f -mtime +$DELETEDAYS -exec rm -f {} \;
else
    find "$BASEFOLDER" -name "*.tar" -type f -mtime +$DELETEDAYS -exec echo "Delete: " {} \;
fi

exit 0