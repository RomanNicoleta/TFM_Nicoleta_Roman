document.getElementById('generateReportBtn').addEventListener('click', function() {
    const policy = document.getElementById('policySelect').value;
    const request = document.getElementById('requestSelect').value;
    const currentTime = document.getElementById('currentTime').value;
    const target = document.getElementById('target').value;

    // Prepare the policies data (you can expand this with your actual data)
    let policyData = [];
    
    if (policy === "policy13") {
        policyData = [
            {
                "@context": "http://www.w3.org/ns/odrl.jsonld",
                "@type": "Set",
                "uid": "http://example.com/policy/13",
                "permission": [
                    {
                        "uid": "http://example.com/policy/13/permission/1",
                        "target": "http://example.com/document/1234",
                        "assigner": "http://example.com/party/16",
                        "action": "distribute",
                        "constraint": [
                            {
                                "@id": "http://example.com/constraint/1",
                                "leftOperand": "dateTime",
                                "operator": "lt",
                                "rightOperand": { "@value": "2018-01-01", "@type": "xsd:date" }
                            }
                        ]
                    }
                ]
            }
        ];
    }
    else if (policy === "policy14") {
        policyData = [
            {
                "@context": "http://www.w3.org/ns/odrl.jsonld",
                "@type": "Offer",
                "uid": "http://example.com/policy:6161",
                "profile": "http://example.com/odrl:profile:10",
                "permission": [
                    {
                        "target": "http://example.com/document:1234",
                        "assigner": "http://example.com/org:616",
                        "action": [
                            {
                                "rdf:value": { "@id": "odrl:print" },
                                "refinement": [
                                    {
                                        "leftOperand": "resolution",
                                        "operator": "lteq",
                                        "rightOperand": { "@value": "1200", "@type": "xsd:integer" },
                                        "unit": "http://dbpedia.org/resource/Dots_per_inch"
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ];
    }
    else if (policy === "policy15") {
        policyData = [
            {
                "@context": "http://www.w3.org/ns/odrl.jsonld",
                "@type": "Offer",
                "uid": "http://example.com/policy:88",
                "profile": "http://example.com/odrl:profile:10",
                "permission": [
                    {
                        "target": "http://example.com/book/1999",
                        "assigner": "http://example.com/org/paisley-park",
                        "action": [
                            {
                                "rdf:value": { "@id": "odrl:reproduce" },
                                "refinement": {
                                    "xone": { 
                                        "@list": [ 
                                            { "@id": "http://example.com/p:88/C1" },
                                            { "@id": "http://example.com/p:88/C2" } 
                                        ]
                                    }
                                }
                            }
                        ]
                    }
                ]
            }
        ];
    }

    // Prepare the data to send to API
    const requestData = {
        policies: policyData,
        current_time: currentTime,
        action: request,
        target: target
    };

    // Send the POST request to the FastAPI backend
    fetch('http://127.0.0.1:8000/evaluate-policies/', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestData),
    })
    .then(response => response.json())
    .then(data => {
        // Display the output in the pre tag
        document.getElementById('reportOutput').textContent = JSON.stringify(data.reports, null, 2);
    })
    .catch(error => {
        console.error('Error:', error);
        alert('Error generating report.');
    });
});
