import requests
import time
import socket
from datetime import datetime, timezone
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

URL = "http://logstash:5000"


def try_login():
    opts = Options()
    opts.add_argument("--headless")
    driver = webdriver.Chrome(options=opts)
    driver.get("https://connect.secure.wellsfargo.com/auth/login/present")
    driver.find_element(By.ID, "j_username").send_keys("")
    driver.find_element(By.ID, "j_password").send_keys("")
    driver.find_element(By.ID, "signon-button").click()
    WebDriverWait(driver, 15).until(
        lambda url: url.current_url != "https://connect.secure.wellsfargo.com"
        or "blocked" in url.page_source.lower()
        or "account" in url.page_source.lower()
    )
    ok = "Dashboard" in driver.page_source
    driver.quit()

    return {
        "host": socket.gethostname(),
        "website": "wellsfargo.com",
        "website_url": "https://connect.secure.wellsfargo.com/auth/login/present",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "time": int(time.time()),
        "Success": ok,
        "test_type": "bot-login",
        "metric_type": "web_automation",
    }


if __name__ == "__main__":
    r = requests.post(URL, json=try_login(), timeout=20)
