from flask import Blueprint, request, jsonify, current_app
from firebase_admin import db
from app.routes.status import set_gesture_status_log
from app.services.mqtt_service import publish_metadata
from flasgger.utils import swag_from
from datetime import datetime
import os
import time

gesture_bp = Blueprint("gesture", __name__)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

# 현재 모드에서 제스처 실행
@gesture_bp.route("/gesture", methods=["POST"])
@swag_from(os.path.join(BASE_DIR, "docs/swagger/gesture/gesture_post_handle_gesture.yml"))
def handle_gesture():
    data = request.get_json()
    gesture = data.get("gesture")
    uid = data.get("uid")

    if not gesture or not uid:
        return jsonify({"error" : "uid와 제스처가 없습니다"}), 400

    firestore_db = current_app.config['FIRESTORE_DB']

    # 인식된 손동작 업데이트
    db.reference(f"user_info/{uid}").update({
        "last_gesture": gesture,
        "updatedAt": datetime.now().isoformat()
    })

    mode_ref = firestore_db.collection("users").document(uid).collection("mode_gesture").document(gesture).get()
    selected_mode = mode_ref.to_dict().get("device") if mode_ref.exists else None

    user_info_ref = db.reference(f"user_info/{uid}/current_device")
    current_device = user_info_ref.get()

    # 모드 설정
    if selected_mode:
        # 모드 선택
        if not current_device or current_device == "null":
            user_info_ref.set(selected_mode)
            return jsonify({"message": f"모드 '{selected_mode}'로 설정되었습니다."})
        # 모드 해제
        elif current_device == selected_mode:
            user_info_ref.set("null")
            return jsonify({"message": f"모드 '{selected_mode}'가 해제되었습니다."})
        # 모드 전환
        else:
            user_info_ref.set(selected_mode)
            return jsonify({"message": f"모드 '{current_device}'->'{selected_mode}'로 전환되었습니다."})

    if not current_device or current_device == "null":
        return jsonify({"error": "현재 모드가 설정되어 있지 않습니다."}), 400

    # rtdb에서 매핑 조회
    mapping = db.reference(f"control_gesture/{uid}/{current_device}/{gesture}").get()
    if mapping is None:
        return jsonify({"error": f"모드 '{current_device}'에 제스처 '{gesture}'가 없습니다."}), 404

    control_val = mapping.get("control")
    controls = control_val if isinstance(control_val, list) else [control_val]

    sent = []
    failed = []

    for c in controls:
        metadata = {
            "mode" : current_device,
            "control" : c
        }
        result = publish_metadata(metadata)

        if result.rc != 0:
            failed.append({"control": c, "error" : f"MQTT 전송 실패 (metadata: {result.rc})"}), 500
            break
        else:
            sent.append(metadata)
            set_gesture_status_log(uid, current_device, gesture, c) # 기기 상태 설정 및 로그 기록
            time.sleep(0.3)

    if failed and not sent:
        return jsonify({"error": "모든 전송 실패", "details": failed}), 500
    elif failed:
        return jsonify({"message": "일부 전송 성공", "sent": sent, "failed": failed}), 207
    else:
        return jsonify({"message": "전송 성공", "sent": sent})
