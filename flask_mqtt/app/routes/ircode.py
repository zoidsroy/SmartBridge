from flask import Blueprint, request, jsonify, current_app
from firebase_admin import db
import os

ircode_bp = Blueprint("ircode", __name__)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

# 전자기기 ir코드 등록
@ircode_bp.route("/ircode", methods=["POST"])
def register_ircode():
    data = request.get_json()
    device = data.get("device")
    control = data.get("control")
    code = data.get("code")

    firestore_db = current_app.config['FIRESTORE_DB']

    code_ref = firestore_db.collection("ir_codes").document(f"{device}_{control}")
    code_ref.set({
        "device": device,
        "control": control,
        "code": code
    })

    return jsonify(f"{device}_{control}")
