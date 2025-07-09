import requests
import json
import time

# API endpoint
url = "http://localhost:8080/api/evaluate"

# JSON payload (replace with real data)
payload = {
    "policy": {
  "@context": "http://www.w3.org/ns/odrl.jsonld",
  "@type": "Set",
  "uid": "http://example.com/policy/16",
  "permission": [
    {
      "uid": "http://example.com/policy/16/permission/1",
      "target": "http://example.com/document/5678",
      "assigner": "http://example.com/party/41",
      "action": "access",
      "constraint": [
        {
          "@id": "http://example.com/constraint/4",
          "leftOperand": "dateTime",
          "operator": "gteq",
          "rightOperand": {
            "@value": "2025-01-01T00:00:00Z",
            "@type": "xsd:dateTime"
          }
        },
        {
          "@id": "http://example.com/constraint/5",
          "leftOperand": "dateTime",
          "operator": "lteq",
          "rightOperand": {
            "@value": "2025-12-31T23:59:59Z",
            "@type": "xsd:dateTime"
          }
        }
      ]
    }
  ]
},
    "world": {
  "world": {
    "currentTime": {
      "dateTime": "2025-03-25T10:30:00Z"
    }
  }
},
    "action": "access",
    "target": "http://example.com/document/5678"
}

# Headers
headers = {"Content-Type": "application/json"}

# Number of requests
num_requests = 1000

# Start timing
start_time = time.time()

for i in range(num_requests):
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    if response.status_code != 200:
        print(f"Request {i} failed with status code {response.status_code}")
    else:
        print(f"Request {i} succeeded: {response.json()}")

# End timing
end_time = time.time()

print(f"Sent {num_requests} requests in {end_time - start_time:.2f} seconds")
