from flask import Flask

app = Flask(__name__)

HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>CI/CD Demo</title>
    <style>
        body {
            margin: 0;
            background: #0066cc;
            color: white;
            font-family: Arial, sans-serif;
            text-align: center;
            padding-top: 150px;
        }

        .card {
            width: 600px;
            margin: auto;
            background: rgba(255,255,255,0.15);
            padding: 30px;
            border-radius: 10px;
        }

        .footer {
            position: fixed;
            bottom: 10px;
            right: 20px;
            font-size: 12px;
        }
    </style>
</head>
<body>

<div class="card">
    <h1>🚀 CI/CD Demo project: Application Deployment </h1>
    <h2>Version 3</h2>

    <p>Successfully deployed by Debdip Ghosh:</p>

    <p>
        GitHub → Jenkins → Docker → Docker Hub → Kubernetes
    </p>

    <h3>Application Running Successfully</h3>
</div>

<div class="footer">
    Created by Debdip Ghosh
</div>

</body>
</html>
"""

@app.route("/")
def home():
    return HTML

@app.route("/health")
def health():
    return {"status": "UP"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
