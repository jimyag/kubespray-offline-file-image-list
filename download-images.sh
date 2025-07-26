#!/bin/bash

# 镜像列表文件
IMAGE_LIST_DIR="./images.list"
REGISTRY_PREFIX="registry.i.jimyag.com"


SPECIFIED_IMAGE_LIST_FILE=""

EXEC_CMD=""
if command -v nerdctl 1>/dev/null 2>&1; then
    EXEC_CMD="nerdctl"
elif command -v podman 1>/dev/null 2>&1; then
    EXEC_CMD="podman"
elif command -v docker 1>/dev/null 2>&1; then
    EXEC_CMD="docker"
else
    echo "not found container runtime"
    exit 1
fi

function usage(){
    echo "Usage: $0 [<image-list-file>]"
    echo "  <image-list-file>: specify the image list file to download, default is all files in $IMAGE_LIST_DIR"
    exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "-?" ] || [ "$1" == "-?" ] || [ "$1" == "-h?" ] || [ "$1" == "-?h" ]; then
    usage
fi

if [ -n "$1" ]; then
    SPECIFIED_IMAGE_LIST_FILE="$1"
fi

function download_one_image() {
    local image="$1"

    # 跳过空行
    [ -z "$image" ] && return

    echo "==> begin to process image: $image"

    # 构造带前缀的新镜像名
    new_image="${REGISTRY_PREFIX}/${image}"

    # 判断远程镜像是否存在
    if $EXEC_CMD manifest inspect "$new_image" > /dev/null 2>&1; then
        echo "remote image: $new_image already exists, skip"
        return
    fi

    # 拉取镜像
    $EXEC_CMD pull "$image"

    # 添加新 tag
    $EXEC_CMD tag "$image" "$new_image"

    echo "rename image: $new_image"

    # 如果需要推送到 registry，则取消下面的注释
    $EXEC_CMD push "$new_image"
    echo
}


function download_images_from_file() {
    local file="$1"
    echo "==> begin to process file: $file"

    while read -r image; do
        download_one_image "$image"
    done < "$file"

    echo "==> process file: $file done"
}

if [ -n "$SPECIFIED_IMAGE_LIST_FILE" ]; then
    download_images_from_file "$IMAGE_LIST_DIR/$SPECIFIED_IMAGE_LIST_FILE"
    exit 0
fi

# 遍历images.list目录下的所有文件
for file in "$IMAGE_LIST_DIR"/*.list; do
    download_images_from_file "$file"
done

