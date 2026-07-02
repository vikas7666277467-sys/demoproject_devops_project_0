import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template


APP_VERSION = os.getenv("APP_VERSION", "1")
app = Flask(__name__)


@app.get("/")
def home():
    return render_template(
        "index.html",
        version=APP_VERSION,
        hostname=socket.gethostname(),
    )


@app.get("/health")
def health():
    return jsonify(
        status="healthy",
        version=APP_VERSION,
        timestamp=datetime.now(timezone.utc).isoformat(),
    )


@app.get("/version")
def version():
    return jsonify(version=APP_VERSION)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

