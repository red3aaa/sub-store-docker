#!/bin/sh

# 检查环境变量
if [ -z "$HF_TOKEN" ] || [ -z "$DATASET_ID" ]; then
    echo "缺少必要的环境变量 HF_TOKEN 或 DATASET_ID"
    exit 1
fi

# 上传备份
cat > /tmp/hf_sync.py << 'EOL'
from huggingface_hub import HfApi
import sys
import os

def manage_backups(api, repo_id, max_files=50):
    files = api.list_repo_files(repo_id=repo_id, repo_type="dataset")
    backup_files = [f for f in files if f.startswith('sub-store_backup_') and f.endswith('.json')]
    backup_files.sort()
    
    if len(backup_files) >= max_files:
        files_to_delete = backup_files[:(len(backup_files) - max_files + 1)]
        for file_to_delete in files_to_delete:
            try:
                api.delete_file(path_in_repo=file_to_delete, repo_id=repo_id, repo_type="dataset")
                print(f'已删除旧备份: {file_to_delete}')
            except Exception as e:
                print(f'删除 {file_to_delete} 时出错: {str(e)}')

def upload_backup(file_path, file_name, token, repo_id):
    api = HfApi(token=token)
    try:
        api.upload_file(
            path_or_fileobj=file_path,
            path_in_repo=file_name,
            repo_id=repo_id,
            repo_type="dataset"
        )
        print(f"成功上传 {file_name}")
        
        manage_backups(api, repo_id)
    except Exception as e:
        print(f"文件上传出错: {str(e)}")

# 下载最新备份
def download_latest_backup(token, repo_id):
    try:
        api = HfApi(token=token)
        files = api.list_repo_files(repo_id=repo_id, repo_type="dataset")
        backup_files = [f for f in files if f.startswith('sub-store_backup_') and f.endswith('.json')]
        
        if not backup_files:
            print("未找到备份文件")
            return
            
        latest_backup = sorted(backup_files)[-1]
        
        filepath = api.hf_hub_download(
            repo_id=repo_id,
            filename=latest_backup,
            repo_type="dataset"
        )
        
        if filepath and os.path.exists(filepath):
            os.makedirs('/opt/app/data', exist_ok=True)
            os.system(f'cp "{filepath}" /opt/app/data/sub-store.json')
            print(f"成功从 {latest_backup} 恢复备份")
                
    except Exception as e:
        print(f"下载备份时出错: {str(e)}")

if __name__ == "__main__":
    action = sys.argv[1]
    token = sys.argv[2]
    repo_id = sys.argv[3]
    
    if action == "upload":
        file_path = sys.argv[4]
        file_name = sys.argv[5]
        upload_backup(file_path, file_name, token, repo_id)
    elif action == "download":
        download_latest_backup(token, repo_id)
EOL

# 首次启动时下载最新备份
echo "正在从 HuggingFace 下载最新备份..."
python3 /tmp/hf_sync.py download "${HF_TOKEN}" "${DATASET_ID}"

# 同步函数
sync_data() {
    while true; do
        echo "开始同步进程 $(date)"
        
        if [ -f "/opt/app/data/sub-store.json" ]; then
            timestamp=$(date +%Y%m%d_%H%M%S)
            backup_file="sub-store_backup_${timestamp}.json"
            
            # 复制数据库文件
            cp /opt/app/data/sub-store.json "/tmp/${backup_file}"
            
            echo "正在上传备份到 HuggingFace..."
            python3 /tmp/hf_sync.py upload "${HF_TOKEN}" "${DATASET_ID}" "/tmp/${backup_file}" "${backup_file}"
            
            rm -f "/tmp/${backup_file}"
        else
            echo "数据库文件不存在，等待下次同步..."
        fi
        
        SYNC_INTERVAL=${SYNC_INTERVAL:-7200}
        echo "下次同步将在 ${SYNC_INTERVAL} 秒后进行..."
        sleep $SYNC_INTERVAL
    done
}

# 后台启动同步进程
sync_data &
