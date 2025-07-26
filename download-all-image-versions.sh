#!/bin/bash

set -e

IMAGE_LIST_DIR="./images.list"
REGISTRY_PREFIX="registry.i.jimyag.com"
OUTPUT_DIR="./all-image-versions"
DOWNLOAD_IMAGES=false  # 设置为true来下载镜像

# 支持的容器运行时
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

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "Using container runtime: $EXEC_CMD"
echo "Download images: $DOWNLOAD_IMAGES"

# 临时文件存储所有镜像基础名称
TEMP_FILE=$(mktemp)

# 从所有images.list文件中提取镜像基础名称（不包含版本）
echo "==> extract all image base names..."
for file in "$IMAGE_LIST_DIR"/*.list; do
    if [ -f "$file" ]; then
        echo "Processing: $file"
        while read -r image; do
            # 跳过空行
            [ -z "$image" ] && continue
            
            # 提取基础镜像名称（去掉版本号）
            # 例如: registry.k8s.io/kube-apiserver:v1.32.5 -> registry.k8s.io/kube-apiserver
            base_image="${image%:*}"
            echo "$base_image" >> "$TEMP_FILE"
        done < "$file"
    fi
done

# 去重并排序
sort -u "$TEMP_FILE" > "${TEMP_FILE}.unique"
mv "${TEMP_FILE}.unique" "$TEMP_FILE"

echo "==> found $(wc -l < "$TEMP_FILE") unique image base names"

# 判断tag是否需要保留
is_valid_tag() {
    local tag="$1"
    # 过滤掉以sha256-开头的tag
    if [[ "$tag" =~ ^sha256- ]]; then
        return 1
    fi
    # 你可以在这里添加更多过滤规则
    return 0
}

# 获取Docker Hub镜像的所有标签
get_dockerhub_tags() {
    local base_image
    local tags
    local page
    local api_url
    local response
    local page_tags
    local next_url
    
    base_image="$1"
    tags=""
    page=1
    while true; do
        api_url="https://registry.hub.docker.com/v2/repositories/${base_image#docker.io/}/tags/?page=${page}&page_size=100"
        >&2 echo "  page $page: $api_url"
        response=$(curl -s -L "$api_url")
        page_tags=$(echo "$response" | jq -r '.results[].name' 2>/dev/null || echo "")
        if [ -z "$page_tags" ]; then
            break
        fi
        tags="${tags}"$'\n'"${page_tags}"
        # 检查是否还有下一页
        next_url=$(echo "$response" | jq -r '.next' 2>/dev/null || echo "")
        if [ "$next_url" = "null" ] || [ -z "$next_url" ]; then
            break
        fi
        ((page++))
    done
    echo "$tags"
}

# 获取Quay镜像的所有标签
get_quay_tags() {
    local base_image
    local api_url
    local tags
    
    base_image="$1"
    api_url="https://quay.io/api/v1/repository/${base_image#quay.io/}/tag/"
    >&2 echo "query tags: $api_url"
    tags=$(curl -s -L "$api_url" | jq -r '.tags[].name' 2>/dev/null || echo "")
    echo "$tags"
}

# 获取Kubernetes官方镜像的所有标签
get_k8s_tags() {
    local base_image
    local api_url
    local tags
    
    base_image="$1"
    api_url="https://registry.k8s.io/v2/${base_image#registry.k8s.io/}/tags/list"
    >&2 echo "query tags: $api_url"
    tags=$(curl -s -L "$api_url" | jq -r '.tags[]' 2>/dev/null || echo "")
    echo "$tags"
}

# 特殊处理某些镜像的标签获取逻辑
get_special_tags() {
    local base_image
    local api_url
    local tags
    
    base_image="$1"
    
    case "$base_image" in
        "docker.io/envoyproxy/envoy")
            >&2 echo "Getting envoyproxy/envoy tags from GitHub releases"
            # 通过GitHub API获取envoyproxy/envoy的release版本
            api_url="https://api.github.com/repos/envoyproxy/envoy/releases"
            tags=$(curl -s -L "$api_url" | jq -r '.[].tag_name' 2>/dev/null | head -50 || echo "")
            echo "$tags"
            ;;
        *)
    esac
}

# 保存镜像的所有版本到文件
save_all_versions() {
    local base_image
    local output_file
    local tags
    
    base_image="$1"
    output_file="$OUTPUT_DIR/${base_image//\//_}.list"
    
    echo "==> process image: $base_image"
    echo "save to: $output_file"
    
    # 清空输出文件
    : > "$output_file"
    
    # 首先尝试特殊处理
    echo "Trying special handling for $base_image"
    tags=$(get_special_tags "$base_image")
    if [ $? -eq 0 ] && [ -n "$tags" ]; then
        # 特殊处理成功，使用获取到的标签
        echo "Using special handling for $base_image"
    else
        # 根据镜像仓库类型获取标签
        echo "Using standard handling for $base_image"
        tags=""
        if [[ "$base_image" == *"registry.k8s.io"* ]]; then
            echo "Getting tags from registry.k8s.io"
            tags=$(get_k8s_tags "$base_image")
        elif [[ "$base_image" == *"quay.io"* ]]; then
            echo "Getting tags from quay.io"
            tags=$(get_quay_tags "$base_image")
        elif [[ "$base_image" == *"docker.io"* ]]; then
            echo "Getting tags from docker.io"
            tags=$(get_dockerhub_tags "$base_image")
        else
            echo "unknown image repository format: $base_image, skip"
            return
        fi
    fi
    
    if [ -z "$tags" ]; then
        echo "cannot get tags list for $base_image, skip"
        return
    fi
    
    echo "found tags: $(echo "$tags" | wc -l)"
    
    # 保存每个版本到文件
    while read -r tag; do
        if [ -n "$tag" ] && is_valid_tag "$tag"; then
            full_image="${base_image}:${tag}"
            echo "$full_image" >> "$output_file"
            
            # 如果需要下载镜像
            if [ "$DOWNLOAD_IMAGES" = true ]; then
                echo "   download: $full_image"
                
                # 构造带前缀的新镜像名
                new_image="${REGISTRY_PREFIX}/${full_image}"
                
                # 判断远程镜像是否存在
                if $EXEC_CMD manifest inspect "$new_image" > /dev/null 2>&1; then
                    echo "    remote image already exists: $new_image, skip"
                    continue
                fi
                
                # 拉取镜像
                if $EXEC_CMD pull "$full_image"; then
                    # 添加新 tag
                    $EXEC_CMD tag "$full_image" "$new_image"
                    echo "    rename image: $new_image"
                    
                    # 推送到 registry
                    $EXEC_CMD push "$new_image"
                    echo "    push image: $new_image"
                else
                    echo "    download image: $full_image failed"
                fi
            fi
        fi
    done <<< "$tags"
    
    echo "saved $(wc -l < "$output_file") image versions to $output_file"
    echo
}

# 处理每个基础镜像
while read -r base_image; do
    save_all_versions "$base_image"
done < "$TEMP_FILE"

# 清理临时文件
rm -f "$TEMP_FILE"

echo "==> all image versions saved to $OUTPUT_DIR/"
echo "==> to download images, please set DOWNLOAD_IMAGES=true in the script" 
