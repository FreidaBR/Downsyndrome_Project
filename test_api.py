import requests

url = "http://127.0.0.1:5000/api/process"
files = {'audio': open('test_audio/pizza_please_1.wav', 'rb')}
try:
    r = requests.post(url, files=files)
    print("Status:", r.status_code)
    try:
        print(r.json())
    except:
        print(r.text)
except requests.exceptions.RequestException as e:
    print("Fetch Failed:", e)
