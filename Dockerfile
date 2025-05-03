FROM xream/sub-store:latest
run mkdir -p /opt/app/data

WORKDIR /opt/app

# 安装必要依赖
RUN apk add --no-cache nodejs python3 py3-pip && \
    mkdir -p /opt/venv && \
    python3 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install huggingface_hub requests webdavclient3 && \
    chmod 777 -R /opt/app

# 复制备份脚本
COPY sync_data.sh .
RUN chmod +x /opt/app/sync_data.sh
copy start.sh .


# 启动 Sub-Store 并在后台运行备份脚本
CMD	./start.sh
