#!/bin/bash

FILE_LIST_DIR="./files.list"
BASE_DIR="./releases"

SPECIFIED_FILE_LIST_FILE=""

function usage(){
    echo "Usage: $0 [<file-list-file>] [--help]"
    echo "  <file-list-file>: specify the file list file to download, default is all files in $FILE_LIST_DIR"
    echo "  --help: show this help message"
    exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "-?" ] || [ "$1" == "-?" ] || [ "$1" == "-h?" ] || [ "$1" == "-?h" ]; then
    usage
fi

if [ -n "$1" ]; then
    SPECIFIED_FILE_LIST_FILE="$1"
fi

function download_one_file() {
    local url="$1"

    # 跳过空行
    [ -z "$url" ] && return

    echo "==> begin to process release file: $url"

    relative_path="${url#*://}"

    # 构造完整保存路径
    save_path="${BASE_DIR}/${relative_path}"

    # 创建目录
    mkdir -p "$(dirname "$save_path")"
    
    # 判断文件是否存在
    if [ -f "$save_path" ]; then
        echo "release file: $save_path already exists, skip"
        return
    fi

    curl -L --fail --silent --show-error -o "$save_path" "$url" || {
        echo "download release file: $url failed"
        return
    }

    echo "save release file: $save_path success"
    echo
}


function download_releases_from_file() {
    local file="$1"
    echo "==> begin to process file: $file"

    while read -r url; do
        download_one_file "$url"
    done < "$file"

    echo "==> process file: $file done"
    echo
}


if [ -n "$SPECIFIED_FILE_LIST_FILE" ]; then
    download_releases_from_file "$FILE_LIST_DIR/$SPECIFIED_FILE_LIST_FILE"
    exit 0
fi


for file in "$FILE_LIST_DIR"/*.list; do
    download_releases_from_file "$file"
done