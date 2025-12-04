from flask import Flask
from flask import request
from flask import json

app = Flask(__name__)

request_number = -1 

@app.route("/", methods=["POST"])
def main_route():
    global request_number
    tmpp_request_number = int(request.json["request_number"])
    if(tmpp_request_number > request_number):
        request_number = tmpp_request_number
        print("request_number", request.json["request_number"],
              "LED_Control:", request.json["LED_Control"],
              "left:", request.json["left_position"], 
              "mid_x:", request.json["mid_x"],
              "mid_y:", request.json["mid_y"],
              "right:", request.json["right_position"],
              "pump:", request.json["pump"])
    response = {"time": "1970",
	    "response": "200"}
    return json.dumps(response)

@app.route("/test")
def test_route():
    return "Hello "
