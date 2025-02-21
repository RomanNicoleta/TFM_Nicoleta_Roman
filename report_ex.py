from datetime import datetime
import json

class ODRLEvaluator:
    def __init__(self, policies, current_time):
        self.policies = policies  # List of policies
        self.current_time = datetime.strptime(current_time, "%Y-%m-%dT%H:%M:%S.%fZ")
    
    def evaluate_activation_state(self, permission):
        for constraint in permission.get("constraint", []):
            if constraint["leftOperand"] == "dateTime" and constraint["operator"] == "lt":
                constraint_time = datetime.strptime(constraint["rightOperand"]["@value"], "%Y-%m-%d")
                if self.current_time < constraint_time:
                    return "Active"
        return "Inactive"
    
    def evaluate_access(self, policy, action, target):
        reports = []
        for permission in policy.get("permission", []):
            activation_state = self.evaluate_activation_state(permission)
            if activation_state == "Active" and permission["action"] == action and permission["target"] == target:
                reports.append({
                    "@context": {
                        "report": "https://w3c/report",
                        "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
                    },
                    "report": "Yes, you can because the permission is active and the requested action is allowed.",
                    "permission": permission,
                    "activation_state": activation_state,
                    "access_control": "Permit",
                    "rdfs:comment": "The requested action was permitted based on the current time and constraints.",
                    "policy_uid": policy["uid"]
                })
            else:
                reports.append({
                    "@context": {
                        "report": "https://w3c/report",
                        "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
                    },
                    "report": "No, you cannot because the permission is inactive or the requested action is not allowed.",
                    "permission": permission,
                    "activation_state": activation_state,
                    "access_control": "Deny",
                    "rdfs:comment": "The requested action was denied because the permission is not active or does not match the requested action/target.",
                    "policy_uid": policy["uid"]
                })
        return reports
    
    def evaluate_all_policies(self, action, target):
        all_reports = []
        for policy in self.policies:
            policy_reports = self.evaluate_access(policy, action, target)
            all_reports.extend(policy_reports)
        return all_reports

# Define multiple policies
policies = [
    {
        # Example 13 available on https://w3c.github.io/odrl/formal-semantics/examples/policy13.json
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
    {
        # Example 14 available on https://www.w3.org/TR/odrl-model/#constraint-action
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
    {
        # Example 15 available on https://www.w3.org/TR/odrl-model/#constraint-action
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
    },
    {
        "@context": "http://www.w3.org/ns/odrl.jsonld",
        "@type": "Constraint",
        "uid": "http://example.com/p:88/C1",
        "leftOperand": "media",
        "operator": "eq",
        "rightOperand": { "@value": "online", "@type": "xsd:string" }
    },
    {
        "@context": "http://www.w3.org/ns/odrl.jsonld",
        "@type": "Constraint",
        "uid": "http://example.com/p:88/C2",
        "leftOperand": "media",
        "operator": "eq",
        "rightOperand": { "@value": "print", "@type": "xsd:string" }
    }
]

# Current time, action, and target
current_time = "2017-12-31T23:59:59.999Z"
action = "distribute"
target = "http://example.com/document/1234"

# Evaluation stage
evaluator = ODRLEvaluator(policies, current_time)
reports = evaluator.evaluate_all_policies(action, target)

# Generate Reports
for report in reports:
    print(json.dumps(report, indent=2))
