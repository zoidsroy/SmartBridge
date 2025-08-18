from flask import Blueprint, request, jsonify, current_app
from firebase_admin import db
from flasgger.utils import swag_from
from datetime import datetime
import os

status_bp = Blueprint("log", __name__)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

def infer_device_status(uid, device, control):
    cyclic_logs = {
        "light": {
            "color": ["전구색(Warm)", "주광색(Cool)", "주백색(Natural)"]
        },
        "fan": {
            "mode": ["normal", "natural", "sleep", "eco"]
        }
    }

    # 현재 상태 가져오기
    current_power = db.reference(f"status/{uid}/{device}/power").get() or "off"
    log_data = db.reference(f"status/{uid}/{device}/log").get()
    current_log = log_data if isinstance(log_data, dict) else {}

    # power 설정
    if control == "power":
        power = "off" if current_power == "on" else "on"
        log = {"power": power}
        if device == "fan" and power == "off":
            log["timer"] = "0"
        return power, log
    
    # cyclic log 설정
    cyclic = cyclic_logs.get(device, {}).get(control)
    if cyclic:
        prev = current_log.get(control)
        if prev in cyclic:
            idx = (cyclic.index(prev) + 1) % len(cyclic)
        else:
            idx = 0
        current_log[control] = cyclic[idx]

    current_log["last_control"] = control

    return current_power, current_log

def update_light_log(control, log, log_ref):
    if control != "color":
        current_log = log_ref.get() or {}
        color = current_log.get("color")
        if color:
            log["color"] = color

    return log

def update_fan_log(control, log, log_ref):
    current_log = log_ref.get() or {}
    fan_mode = current_log.get("mode")
    wind_power = current_log.get("wind_power", "1")
    timer = current_log.get("timer", "0")

    if wind_power:
        log["wind_power"] = wind_power
    if timer:
        log["timer"] = timer

    if control == "mode":
        if log.get("mode") == "eco" and wind_power:
            log["wind_power"] = "2"
        else:
            pass
    elif control in ["stronger", "weaker"]:
        if fan_mode == "eco":
            log["wind_power"] = "2"
        elif wind_power:
            wp = int(wind_power)
            wp = wp + 1 if control == "stronger" and wp < 12 else wp
            wp = wp - 1 if control == "weaker" and wp > 1 else wp
            log["wind_power"] = str(wp)

        if fan_mode:
            log["mode"] = fan_mode
    elif control == "timer":
        if timer:
            t = float(timer)
            t = t + 0.5 if t < 7.5 else 0.0
        log["timer"] = str(t)

        if fan_mode:
            log["mode"] = fan_mode
    else:      
        if fan_mode:
            log["mode"] = fan_mode
        if log.get("power") == "off":
            log["timer"] = "0.0"
    
    return log

def record_log(uid, device, control, power, log, extra={}):
    # 상태 업데이트
    db.reference(f"status/{uid}/{device}/power").set(power)
    db.reference(f"status/{uid}/{device}/log").set(log)
    
    # 상태 정보 불러오기
    status_ref = db.reference(f"status/{uid}/{device}").get() or {}
    power = status_ref.get("power", "unknown")
    log = status_ref.get("log", {})

    color = log.get("color", "unknown")
    wind_power = log.get("wind_power", "unknown")
    fan_mode = log.get("mode", "unknown")

    # 로그 기록
    log_entry = {
        "createdAt": datetime.now().isoformat(),
        "device": device,
        **extra, #gesture / voice
        "control": control,
        "power" : power,
        "color" : color,
        "wind_power" : wind_power,
        "fan_mode" : fan_mode
    }
    firestore_db = current_app.config['FIRESTORE_DB']
    firestore_db.collection("users").document(uid).collection("logs").add(log_entry)

def set_gesture_status_log(uid, device, gesture, control):
    power, log = infer_device_status(uid, device, control)

    log_ref = db.reference(f"status/{uid}/{device}/log")
    # log 고정 변수 설정
    if device == "light":
        log = update_light_log(control, log, log_ref)
    elif device == "fan":
        log = update_fan_log(control, log, log_ref)
    
    record_log(uid, device, control, power, log, {"gesture": gesture})

def set_voice_status_log(uid, device, voice, control):
    power, log = infer_device_status(uid, device, control)

    log_ref = db.reference(f"status/{uid}/{device}/log")
    # log 고정 변수 설정
    if device == "light":
        log = update_light_log(control, log, log_ref)
    elif device == "fan":
        log = update_fan_log(control, log, log_ref)
    
    record_log(uid, device, control, power, log, {"voice": voice})