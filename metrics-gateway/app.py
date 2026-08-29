from flask import Flask, request, jsonify, Response


app = Flask(__name__)
metrics_store = {}

@app.route("/update-metric", methods=["PUT"])
def update_metric():
    data = request.get_json()
    name = data.get("metric_name")
    value = data.get("value")
    labels = data.get("labels", {})

    if not name or value is None:
        return jsonify({"error": "metric_name and value are required"}), 400

    metrics_store[name] = {"value": value, "labels": labels}
    return jsonify({"message": f"{name} updated to {value}"}), 200

@app.route("/metrics", methods=["GET"])
def get_metrics():
    lines = []
    for name, entry in metrics_store.items():
        if entry["labels"]:
            label_str = ",".join(f'{k}="{v}"' for k, v in entry["labels"].items())
            lines.append(f'{name}{{{label_str}}} {entry["value"]}')
        else:
            lines.append(f'{name} {entry["value"]}')
    return Response("\n".join(lines) + "\n", mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)

