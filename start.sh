/sync_data.sh &
export SUB_STORE_BACKEND_API_HOST=127.0.0.1
export SUB_STORE_FRONTEND_HOST=0.0.0.0
export SUB_STORE_FRONTEND_PORT=7860
export SUB_STORE_FRONTEND_PATH=/opt/app/frontend
export SUB_STORE_DATA_BASE_PATH=/opt/app/data

node /opt/app/sub-store.bundle.js