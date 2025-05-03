#!/bin/bash

mkdir -p ./data

# 生成校验和文件
generate_sum() {
    local file=$1
    local sum_file=$2
    sha256sum "$file" > "$sum_file"
}

# 优先从WebDAV恢复数据
if [ ! -z "$WEBDAV_URL" ] && [ ! -z "$WEBDAV_USERNAME" ] && [ ! -z "$WEBDAV_PASSWORD" ]; then
    echo "尝试从WebDAV恢复数据..."
    curl -L --fail --user "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" "$WEBDAV_URL/sub-store.json" -o "/opt/app/data/sub-store.json" && {
        echo "从WebDAV恢复数据成功"
    }
else
    echo "未配置WebDAV,跳过数据恢复"
fi

# 同步函数
sync_data() {
    while true; do
        echo "开始同步..."
        HOUR=$(date +%H)
        
        if [ -f "/opt/app/data/sub-store.json" ]; then
            # 生成新的校验和文件
            generate_sum "/opt/app/data/sub-store.json" "/opt/app/data/sub-store.json.new"
            
            # 检查文件是否变化
            if [ ! -f "/opt/app/data/sub-store.json.sha256" ] || ! cmp -s "/opt/app/data/sub-store.json.sha256.new" "/opt/app/data/sub-store.json.sha256"; then
                echo "检测到文件变化，开始同步..."
                mv "/opt/app/data/sub-store.json.new" "/opt/app/data/sub-store.json.sha256"
                
                # 同步到WebDAV
                if [ ! -z "$WEBDAV_URL" ] && [ ! -z "$WEBDAV_USERNAME" ] && [ ! -z "$WEBDAV_PASSWORD" ]; then
                    echo "同步到WebDAV..."
                    
                    # 上传数据文件
                    curl -L -T "/opt/app/data/sub-store.json" --user "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" "$WEBDAV_URL/sub-store.json" && {
                        echo "WebDAV更新成功"
                        
                        # 每日备份(包括WebDAV和GitHub)，在每天0点进行
                        if [ "$HOUR" = "00" ]; then
                            echo "开始每日备份..."
                            
                            # 获取前一天的日期
                            YESTERDAY=$(date -d "yesterday" '+%Y%m%d')
                            FILENAME_DAILY="sub-store_${YESTERDAY}.json"
                            
                            # WebDAV每日备份
                            curl -L -T "/opt/app/data/sub-store.json" --user "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" "$WEBDAV_URL/$FILENAME_DAILY" && {
                                echo "WebDAV日期备份成功: $FILENAME_DAILY"
                            } || echo "WebDAV日期备份失败"
                        fi
                    } || {
                        echo "WebDAV上传失败,重试..."
                        sleep 10
                        curl -L -T "/opt/app/data/sub-store.json" --user "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" "$WEBDAV_URL/sub-store.json" || {
                            echo "WebDAV重试失败"
                        }
                    }
                fi
            else
                echo "文件未发生变化，跳过同步"
                rm -f "/opt/app/data/sub-store.json.sha256.new"
            fi
        else
            echo "未找到sub-store.json,跳过同步"
        fi
        
        echo "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "下次同步: $(date -d '+5 minutes' '+%Y-%m-%d %H:%M:%S')"
        sleep 300
    done
}

# 启动同步进程
sync_data &