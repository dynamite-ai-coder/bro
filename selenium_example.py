import os
import sys
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


def create_driver():
    options = Options()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-first-run')
    options.add_argument('--no-default-browser-check')
    options.add_argument('--window-size=1280,800')
    options.binary_location = os.environ.get('CHROME_BIN', '/usr/bin/google-chrome')

    if os.environ.get('SELENIUM_HEADLESS', '').lower() in ('1', 'true', 'yes'):
        options.add_argument('--headless=new')

    return webdriver.Chrome(options=options)


def main():
    print('Starting Selenium test...')
    driver = create_driver()

    try:
        driver.get('https://duckduckgo.com/')

        search_box = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.NAME, 'q'))
        )
        search_box.send_keys('Hello from Selenium!')
        search_box.submit()

        WebDriverWait(driver, 20).until(
            lambda d: 'Hello from Selenium' in d.title or 'DuckDuckGo' in d.title
        )
        print(f'Page title: {driver.title}')

        time.sleep(2)
        print('Selenium test completed successfully!')
        return 0
    except Exception as exc:
        print(f'Error: {exc}')
        return 1
    finally:
        driver.quit()


if __name__ == '__main__':
    sys.exit(main())
