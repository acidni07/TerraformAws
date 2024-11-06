import os

def lambda_handler(event, context):
    myEnvVar = os.environ.get('TITLE')

    res = {
        "statuscode": 200,
        "headers': {
            "content-type: application/json"
        },
        body: "Message from " + myEnvVar + "."
    }
    return res