#!/bin/bash

set -e

KUBESPRAY_REPO="https://github.com/kubernetes-sigs/kubespray.git"
KUBESPRAY_DIR="kubespray"
FILES_DIR="files.list"
IMAGES_DIR="images.list"


# 检查uv是否存在
if ! command -v uv &> /dev/null; then
    echo "==> uv not found, install uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
# 检查虚拟环境是否存在
if [ ! -d ".venv" ]; then
    uv sync
fi

source .venv/bin/activate


# 1. clone 或更新kubespray仓库
echo "==> 检查kubespray仓库..."
if [ ! -d "$KUBESPRAY_DIR/.git" ]; then
    echo "==> clone kubespray..."
    git clone "$KUBESPRAY_REPO" "$KUBESPRAY_DIR"
else
    echo "==> kubespray已存在，执行更新..."
    cd "$KUBESPRAY_DIR"
    git fetch --all --tags
    git pull
    cd -
fi

cd "$KUBESPRAY_DIR"

# 2. 获取所有release tag
echo "==> 获取所有release tag..."
TAGS=$(git tag | sort -V)

for TAG in $TAGS; do
    echo "==> 处理release: $TAG"
    git checkout "$TAG"
    # 确保有contrib/offline/generate_list.sh
    if [ ! -f "contrib/offline/generate_list.sh" ]; then
        echo "==> $TAG 没有contrib/offline/generate_list.sh，跳过"
        continue
    fi
    # 清理旧的temp目录
    rm -rf contrib/offline/temp
    mkdir -p contrib/offline/temp
    # 运行generate_list.sh
    bash contrib/offline/generate_list.sh
    # 检查生成的文件
    if [ ! -f "contrib/offline/temp/files.list" ] || [ ! -f "contrib/offline/temp/images.list" ]; then
        echo "==> $TAG 没有生成files.list或images.list，跳过"
        continue
    fi
    # 拷贝到根目录对应目录并重命名
    cp contrib/offline/temp/files.list "../$FILES_DIR/${TAG}.list"
    cp contrib/offline/temp/images.list "../$IMAGES_DIR/${TAG}.list"
    echo "==> $TAG 处理完成"
done

echo "==> 所有release处理完成" 