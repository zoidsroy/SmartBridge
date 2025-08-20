from flask import Blueprint, request, jsonify, current_app
from firebase_admin import db
from flasgger.utils import swag_from
from datetime import datetime
import os

dashboard_bp = Blueprint("dashboard", __name__)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

def unmapped_controls_func(uid, mode):
    firestore_db = current_app.config['FIRESTORE_DB']

    # 가능한 컨트롤(버튼) 목록
    ircode_ref = firestore_db.collection("ir_codes")
    query = ircode_ref.where('device', '==', mode).stream()

    all_controls = set()
    if mode == "tv" or mode == "curtain":
        all_controls.add("power") # 예외 : tv power 강제 포함

    for doc in query:
        data = doc.to_dict()
        ctrl = data.get("control")
        if isinstance(ctrl, str):
            all_controls.add(ctrl)
        elif isinstance(ctrl, list):
            all_controls.update([c for c in ctrl if isinstance(c, str)])

    # 이미 매핑된 컨트롤(버튼) 목록
    gestures_data = db.reference(f"control_gesture/{uid}/{mode}").get() or {}
    used_controls = set()
    for mapping in gestures_data.values():
        if not isinstance(mapping, dict) or "control" not in mapping:
            continue
        val = mapping["control"]
        if isinstance(val, list) and mode == "tv":
            used_controls.add("power")
        elif isinstance(val, str):
            used_controls.add(val)

    return list(all_controls - used_controls)

# 손동작과 매핑되지 않은 컨트롤(버튼) 목록 조회
@dashboard_bp.route("/dashboard/unmapped_controls", methods=["GET"])
@swag_from(os.path.join(BASE_DIR, "docs/swagger/dashboard/dashboard_get_unmapped_controls.yml"))
def get_unmapped_controls():
    mode = request.args.get("mode")
    uid = request.args.get("uid")

    if not mode or not uid:
        return jsonify({"error" : "uid와 mode 파라미터가 필요합니다."}), 400

    unmapped_controls = unmapped_controls_func(uid, mode)
    return jsonify(unmapped_controls)

# 손동작과 매핑된 컨트롤(버튼) 목록 조회
@dashboard_bp.route("/dashboard/mapped_controls", methods=["GET"])
@swag_from(os.path.join(BASE_DIR, "docs/swagger/dashboard/dashboard_get_mapped_controls.yml"))
def get_mapped_controls():
    mode = request.args.get("mode")
    uid = request.args.get("uid")

    if not mode or not uid:
        return jsonify({"error" : "uid와 mode 파라미터가 필요합니다."}), 400

    # 이미 매핑된 컨트롤(버튼) 목록
    gestures_data = db.reference(f"control_gesture/{uid}/{mode}").get() or {}
    used_controls = set()
    for mapping in gestures_data.values():
        if not isinstance(mapping, dict) or "control" not in mapping:
            continue
        val = mapping["control"]
        if isinstance(val, list) and mode == "tv":
            used_controls.add("power")
        elif isinstance(val, str):
            used_controls.add(val)

    return jsonify(list(used_controls))

def unmapped_gestures_func(uid, mode):
    firestore_db = current_app.config['FIRESTORE_DB']

    # 가능한 손동작 목록
    gestures_ref = firestore_db.collection("gesture_list").get()
    all_gestures = set()
    for doc in gestures_ref:
        all_gestures.add(doc.id)

    # 이미 매핑된 손동작 목록
    # rtdb
    controls_data = db.reference(f"control_gesture/{uid}/{mode}").get() or {}
    used_gestures = set(controls_data.keys())
    # firestore
    fs_gesture_ref = firestore_db.collection("users").document(uid).collection("mode_gesture").stream()
    for doc in fs_gesture_ref:
        used_gestures.add(doc.id)

    return list(all_gestures - used_gestures)

# 컨트롤(버튼)과 매핑되지 않은 손동작 목록 조회
@dashboard_bp.route("/dashboard/unmapped_gestures", methods=["GET"])
@swag_from(os.path.join(BASE_DIR, "docs/swagger/dashboard/dashboard_get_unmapped_gestures.yml"))
def get_unmapped_gestures():
    mode = request.args.get("mode")
    uid = request.args.get("uid")

    if not mode or not uid:
        return jsonify({"error" : "uid와 mode 파라미터가 필요합니다."}), 400

    unmapped_gestures = unmapped_gestures_func(uid, mode)
    return jsonify(unmapped_gestures)

# 손동작, 컨트롤(버튼) 매핑 정보 등록
@dashboard_bp.route("/dashboard/register_mapping", methods=["POST"])
@swag_from(os.path.join(BASE_DIR, "docs/swagger/dashboard/dashboard_post_register_mapping.yml"))
def register_mapping():
    data = request.get_json()
    gesture = data.get("gesture")
    mode = data.get("mode")
    control = data.get("control")
    uid = data.get("uid")

    if not all([gesture, control, mode, uid]):
        return jsonify({"error": "uid, mode, gesture, control은 모두 필요합니다."}), 400

    firestore_db = current_app.config['FIRESTORE_DB']
    cg = firestore_db.collection("users").document(uid).collection("control_gesture")
    doc_ref = cg.document(f"{mode}_{control}")
    snap = doc_ref.get()

    # 삭제
    if snap.exists:
        try:
            # firestore에서 삭제
            doc_ref.delete()
            # rtdb에 삭제
            db.reference(f"control_gesture/{uid}/{mode}/{gesture}").delete()

            return jsonify({
                "message": f"모드 '{mode}'에서 control '{control}'가 삭제되었습니다."
            })
        except Exception as e:
            return jsonify({"error": f"삭제 중 오류: {e}"}), 500

    # 등록
    else:
        # 매핑되지 않은 손동작인지 확인
        unmapped_gestures = unmapped_gestures_func(uid, mode)
        if gesture not in unmapped_gestures:
            return jsonify({"error": "gesture가 유효하지 않습니다."}), 400

        # 매핑되지 않은 컨트롤인지 확인
        unmapped_controls = unmapped_controls_func(uid, mode)
        if control not in unmapped_controls:
            return jsonify({"error": "control이 유효하지 않습니다."}), 400

        # firestore에 등록
        control_sequence = None
        if mode == "tv" and control == "power":
            control_sequence = ["tvPower", "settopPower"] # tv 전원 시퀀스 구성

        firestore_db.collection("users").document(uid).collection("control_gesture").document(f"{mode}_{control}").set({
            "device": mode,
            "gesture": gesture,
            "control": control_sequence if control_sequence else control
        })
        # rtdb에 등록
        db.reference(f"control_gesture/{uid}/{mode}/{gesture}").set({
            "control": control_sequence if control_sequence else control
        })

        return jsonify({
            "message": f"제스처 '{gesture}'가 모드 '{mode}'의 control '{control}'로 등록되었습니다."
        })


# 손동작, 컨트롤(버튼) 매핑 정보 수정
@dashboard_bp.route("/dashboard/update_mapping", methods=["POST"])
@swag_from(os.path.join(BASE_DIR, "docs/swagger/dashboard/dashboard_post_update_mapping.yml"))
def update_mapping():
    data = request.get_json()
    new_gesture = data.get("new_gesture")
    mode = data.get("mode")
    control = data.get("control")
    uid = data.get("uid")

    if not all([new_gesture, mode, control, uid]):
        return jsonify({"error": "uid, mode, gesture, control은 모두 필요합니다."}), 400

    # 매핑되지 않은 손동작인지 확인
    unmapped_gestures = unmapped_gestures_func(uid, mode)
    if new_gesture not in unmapped_gestures:
        return jsonify({"error": "gesture가 이미 매핑되어 있거나 유효하지 않습니다."}), 400

    # 기존 매핑정보 찾기
    gesture_ref = db.reference(f"control_gesture/{uid}/{mode}")
    mappings = gesture_ref.get() or {}

    old_gesture = None
    for gesture, value in mappings.items():
        if value.get("control") == control:
            old_gesture = gesture
            break

    if not old_gesture:
        return jsonify({"error": f"control '{control}'은 '{mode}'에 매핑되어 있지 않습니다."}), 404

    # 새로운 손동작으로 설정
    # firestore 수정
    firestore_db = current_app.config['FIRESTORE_DB']

    control_ref = firestore_db.collection("users").document(uid).collection("control_gesture")
    control_ref.document(f"{mode}_{control}").update({
        "gesture": new_gesture
    })

    # rtdb 수정
    gesture_ref.child(old_gesture).delete()
    db.reference(f"control_gesture/{uid}/{mode}/{new_gesture}").set({
        "control" : control
    })

    return jsonify({
        "message": f"제스처 '{new_gesture}'가 모드 '{mode}'의 control '{control}'로 등록되었습니다."
    })
