from flask import Blueprint, request, jsonify, current_app
from firebase_admin import db
from app.routes.status import set_voice_status_log
from app.services.mqtt_service import publish_metadata
import os
import time

voice_bp = Blueprint("voice", __name__)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

@voice_bp.route("/voice", methods=["POST"])
def handle_voice():
    data = request.get_json()
    voice = data.get("voice")
    uid = data.get("uid")

    print(f"voice: {voice}")

    if not voice or not uid:
        return jsonify({"error" : "uid와 voice 명령어가 모두 필요합니다"}), 400

    # 음성 기반으로 기기, 컨트롤 조회
    firestore_db = current_app.config['FIRESTORE_DB']
    voice_doc = firestore_db.collection("voice_list").document(voice).get()

    if not voice_doc.exists:
        return jsonify({"error": f"'{voice}'를 찾을 수 없습니다."}), 404

    device, control = voice.split("_")
    description = voice_doc.to_dict().get("description", f"{device}_{control}")

    if control in ["on", "off"]:
        control = "power"

    # tv 전원 순차 전송
    if device == "tv" and control == "power":
        controls = ["tvPower", "settopPower"]
    else:
        controls = [control]

    sent = []
    failed = []

    for c in controls:
        metadata = {
            "mode": device,
            "control": c
        }
        result = publish_metadata(metadata)

        if result.rc != 0:
            failed.append({"control": c, "error" : f"MQTT 전송 실패 (metadata: {result.rc})"}), 500
            break
        else:
            sent.append(metadata)
            set_voice_status_log(uid, device, voice, control) # 기기 상태 설정 및 로그 기록
            time.sleep(0.5)

    if failed and not sent:
        return jsonify({"error": "모든 전송 실패", "details": failed}), 500
    elif failed:
        return jsonify({"message": f"'{description}' 일부 전송 성공", "sent": sent, "failed": failed}), 207
    else:
        return jsonify({"message": f"'{description}' 수행 완료", "sent": sent})
