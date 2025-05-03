FROM xream/sub-store:latest

WORKDIR /opt/app
run mkdir -p /opt/app/data
# 安装必要依赖
RUN apk add --no-cache nodejs python3 py3-pip && \
    mkdir -p /opt/venv && \
    python3 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install huggingface_hub requests webdavclient3 && \
    chmod 777 -R /opt/app

# 复制备份脚本
COPY sync_data.sh .
RUN chmod +x /sync_data.sh

# 启动 Sub-Store 并在后台运行备份脚本
CMD	./sync_data.sh && \
    SUB_STORE_BACKEND_API_HOST=127.0.0.1 \
    SUB_STORE_FRONTEND_HOST=0.0.0.0 \
    SUB_STORE_FRONTEND_PORT=7860 \
    SUB_STORE_FRONTEND_PATH=/opt/app/frontend \
    SUB_STORE_DATA_BASE_PATH=/opt/app/data \
    node /opt/app/sub-store.bundle.js
