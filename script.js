// Example policies
const policies = {
    policy13: {
        "@context": "http://www.w3.org/ns/odrl.jsonld",
        "@type": "Set",
        "uid": "http://example.com/policy/13",
        "permission": [{
            "uid": "http://example.com/policy/13/permission/1",
            "target": "http://example.com/document/1234",
            "assigner": "http://example.com/party/16",
            "action": "distribute",
            "constraint": [{
                "@id": "http://example.com/constraint/1",
                "leftOperand": "dateTime",
                "operator": "lt",
                "rightOperand": { "@value": "2018-01-01", "@type": "xsd:date" }
            }]
        }]
    },
    policy14: {
        "@context": "http://www.w3.org/ns/odrl.jsonld",
        "@type": "Offer",
        "uid": "http://example.com/policy:6161",
        "profile": "http://example.com/odrl:profile:10",
        "permission": [{
            "target": "http://example.com/document:1234",
            "assigner": "http://example.com/org:616",
            "action": [{
                "rdf:value": { "@id": "odrl:print" },
                "refinement": [{
                    "leftOperand": "resolution",
                    "operator": "lteq",
                    "rightOperand": { "@value": "1200", "@type": "xsd:integer" },
                    "unit": "http://dbpedia.org/resource/Dots_per_inch"
                }]
            }]
        }]
    },
    policy15: {
        "@context": "http://www.w3.org/ns/odrl.jsonld",
        "@type": "Offer",
        "uid": "http://example.com/policy:88",
        "profile": "http://example.com/odrl:profile:10",
        "permission": [{
            "target": "http://example.com/book/1999",
            "assigner": "http://example.com/org/paisley-park",
            "action": [{
                "rdf:value": { "@id": "odrl:reproduce" },
                "refinement": {
                    "xone": { 
                        "@list": [ 
                            { "@id": "http://example.com/p:88/C1" },
                            { "@id": "http://example.com/p:88/C2" } 
                        ]
                    }
                }
            }]
        }]
    }
};

// Map of recommended actions for each policy
const policyActionMap = {
    'policy13': 'distribute',
    'policy14': 'print',
    'policy15': 'reproduce'
};

// Map of targets for each policy
const policyTargetMap = {
    'policy13': 'http://example.com/document/1234',
    'policy14': 'http://example.com/document:1234',
    'policy15': 'http://example.com/book/1999'
};

// Current selected request and policy
let selectedRequest = null;
let selectedPolicy = null;

// API base URL - you can update this to point to your actual server
const API_BASE_URL = 'http://127.0.0.1:8000';

// Function to load the policy content
function loadPolicy(policyKey) {
    if (!policies[policyKey]) {
        alert("Policy not found.");
        return;
    }
    
    // Set the selected policy
    selectedPolicy = policyKey;
    
    // Update display
    const policyContent = JSON.stringify(policies[policyKey], null, 2);
    document.getElementById('policy-content').textContent = policyContent;
    
    // Suggest appropriate request for this policy
    const suggestedAction = policyActionMap[policyKey];
    if (suggestedAction) {
        setRequest(suggestedAction);
    }
    
    // Clear any previous report
    clearReport();
}

// Function to set the selected request
function setRequest(request) {
    selectedRequest = request;
    
    // Style the buttons to show selection
    const requestButtons = document.querySelectorAll('.sidebar button.choice');
    requestButtons.forEach(button => {
        if (button.textContent.toLowerCase().includes(request.toLowerCase())) {
            button.classList.add('selected');
        } else if (button.textContent.toLowerCase().includes('distribute') || 
                   button.textContent.toLowerCase().includes('print') || 
                   button.textContent.toLowerCase().includes('reproduce')) {
            button.classList.remove('selected');
        }
    });
}

// Function to clear the report
function clearReport() {
    document.getElementById('report-title').style.display = 'none';
    document.getElementById('report-content').style.display = 'none';
    document.getElementById('report-content').textContent = '';
}

// Function to generate the report
async function generateReport() {
    if (!selectedPolicy) {
        alert("Please select a policy before generating the report.");
        return;
    }

    if (!selectedRequest) {
        alert("Please select a request action before generating the report.");
        return;
    }

    // Get the target from the map or use a default
    const target = policyTargetMap[selectedPolicy] || "http://example.com/document/1234";
    
    const requestBody = {
        policies: [policies[selectedPolicy]], // Send the policy as a JSON object
        current_time: new Date().toISOString(),
        action: selectedRequest,
        target: target
    };

    try {
        // Show loading state
        document.getElementById('report-content').textContent = "Loading...";
        document.getElementById('report-title').style.display = 'block';
        document.getElementById('report-content').style.display = 'block';
        
        const response = await fetch(`${API_BASE_URL}/evaluate-policies/`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(requestBody)
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`Server error (${response.status}): ${errorText}`);
        }

        const data = await response.json();
        displayReport(data.reports);
    } catch (error) {
        document.getElementById('report-content').textContent = `Error: ${error.message}`;
    }
}

// Function to display the report
function displayReport(reports) {
    if (!reports || reports.length === 0) {
        document.getElementById('report-content').textContent = "No evaluation results returned.";
        return;
    }
    
    // Format the report nicely
    const formattedReports = reports.map(report => {
        const decision = report.access_control === "Permit" ? "✅ PERMITTED" : "❌ DENIED";
        const reason = report.report;
        
        return `Policy: ${report.policy_uid}
Decision: ${decision}
Reason: ${reason}
Activation State: ${report.activation_state}`;
    }).join("\n\n" + "-".repeat(50) + "\n\n");
    
    document.getElementById('report-title').style.display = 'block';
    document.getElementById('report-content').style.display = 'block';
    document.getElementById('report-content').textContent = formattedReports;
}

// Add CSS class for selected buttons
document.addEventListener('DOMContentLoaded', function() {
    // Add a custom class to style selected buttons
    const style = document.createElement('style');
    style.textContent = '.selected { background-color: #090D41 !important; color: white !important; }';
    document.head.appendChild(style);
});