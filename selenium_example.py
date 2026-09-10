from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

def create_driver():
    options = Options()
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1280,800')
    options.binary_location = '/usr/bin/google-chrome'
    
    driver = webdriver.Chrome(options=options)
    return driver

def main():
    print("Starting Selenium test...")
    driver = create_driver()
    
    try:
        driver.get('https://www.google.com')
        print(f"Page title: {driver.title}")
        
        search_box = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.NAME, "q"))
        )
        search_box.send_keys("Hello from Selenium!")
        search_box.submit()
        
        time.sleep(3)
        print(f"Search results page title: {driver.title}")
        
        print("Selenium test completed successfully!")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        driver.quit()

if __name__ == '__main__':
    main()
