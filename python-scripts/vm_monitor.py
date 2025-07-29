
import psutil
import requests
import time
import platform
import socket
import logging
from datetime import datetime, timezone 
from .logging_config import setup_logging

URL = "http://logstash:5000"
system_logger = setup_logging('system_monitor')

def system_data():
    return {
        "host": socket.gethostname(),
        "os": platform.platform(),
        "cpu_percentage": psutil.cpu_percent(),
        "memory_percentage": psutil.virtual_memory().percent,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "time": int(time.time()),
        "metric_type": "state_management"
    }

if __name__=="__main__":
    try:
        load_data = requests.post(URL,data=system_data(), timeout=5)
        system_logger.info(f"Sent status {load_data.status_code}")

    except Exception as e:
        system_logger.error(f"Error pulling system data {e}")

