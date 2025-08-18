import os
import joblib
import requests
from sklearn.preprocessing import OneHotEncoder
from sklearn.ensemble import RandomForestClassifier
from flask import Blueprint, request, jsonify, current_app
from firebase_admin import db, firestore
from flasgger.utils import swag_from
from datetime import datetime, timedelta
from astral import LocationInfo
from astral.sun import sun
from timezonefinder import TimezoneFinder
import pytz

recommand_bp = Blueprint("recommand", __name__)

OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "bde2733011591df872f6e37f11d51336")

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
MODEL_DIR = os.path.join(BASE_DIR, "models")

MAX_GESTURE_RECOMMEND = 6
MAX_VOICE_RECOMMEND = 3

def get_coordinates(city, api_key):
    try:
        response = requests.get("http://api.openweathermap.org/geo/1.0/direct", params= {
            "q": city,
            "limit": 1,
            "appid": api_key
        })
        data = response.json()  

        if data:
            lat = data[0]["lat"]
            lon = data[0]["lon"]
            return lat, lon
    except:
        pass
    return 37.5665, 126.9780

def get_timezone(lat, lon):
    try:
        tf = TimezoneFinder()
        tz = tf.timezone_at(lat=lat, lng=lon)
        return tz or "Asia/Seoul"
    except:
        return "Asia/Seoul"

def get_user_location(uid):
    firestore_db = current_app.config['FIRESTORE_DB']
    user_doc = firestore_db.collection("users").document(uid).get()

    if user_doc.exists:
        user_data = user_doc.to_dict()
        city = user_data.get("city", "Seoul")
        country = user_data.get("country", "KR")
        lat, lon = get_coordinates(city, OPENWEATHER_API_KEY)
        timezone = get_timezone(lat, lon)

        return LocationInfo(city, country, timezone, lat, lon)

    else:
        return LocationInfo("Seoul", "KR", "Asia/Seoul", latitude=37.5665, longitude=126.9780)


# 현재 기온 가져오기
def get_current_temperature(city, api_key):
    try:
        response = requests.get("https://api.openweathermap.org/data/2.5/weather", params={
            "q": city,
            "appid": api_key,
            "units": "metric"
        })
        data = response.json()
        return float(data["main"]["temp"])
    except Exception as e:
        return 24.0

@recommand_bp.route("/recommend_gesture_voice_auto", methods=["GET"])
@swag_from(os.path.join(BASE_DIR, "docs/swagger/recommend/get_recommend_gesture_voice_auto.yml"))
def recommend_gesture_auto():
    try:
        uid = request.args.get("uid")
        if not uid:
            return jsonify({"error" : "uid가 필요합니다."}), 400

        # 위치, 시간 정보
        location = get_user_location(uid)
        timezone = pytz.timezone(location.timezone)
        now = datetime.now(timezone)
        hour = now.hour
        weekday = now.weekday()
        temp = get_current_temperature(location.name, OPENWEATHER_API_KEY)

        s = sun(location.observer, date=now.date(), tzinfo=timezone)
        sunrise = s["sunrise"]
        sunset = s["sunset"]
        is_morning = sunrise <= now <= sunrise + timedelta(hours=1)
        is_evening = sunset - timedelta(minutes=30) <= now <= sunset + timedelta(hours=2)

        # 현재 모드 가져오기
        current_device = db.reference(f"user_info/{uid}/current_device").get()
        if not current_device:
            return jsonify({"error": "현재 device 정보를 찾을 수 없습니다."}), 400
        
        # mode_gesture 가져오기
        firestore_db = current_app.config['FIRESTORE_DB']
        uid_ref = firestore_db.collection("users").document(uid)
        mode_mappings = uid_ref.collection("mode_gesture").stream()
        
        mode_gestures = {}
        for doc in mode_mappings:
            data = doc.to_dict()
            mode = data.get("device")
            if mode:
                mode_gestures[mode] = doc.id # device : gesture
        
        control_mappings = uid_ref.collection("control_gesture").stream()

        # power_gesture 가져오기
        power_gestures = {}
        for doc in control_mappings:
            data = doc.to_dict()
            device = data.get("device")
            control = data.get("control")
            gesture = data.get("gesture")
            if device and gesture and control == "power":
                power_gestures[device] = gesture # device : gesture                

        # 상태 가져오기
        status_refs = {
            mode: db.reference(f"status/{uid}/{mode}").get() or {} for mode in mode_gestures
        }

        gesture_recommendations = []
        gesture_seen_pairs = set()

        voice_recommendations = []
        voice_seen_pairs = set()

        def add_gesture_recommendation(device, gesture, reason):
            pair = (device, gesture)
            if pair not in gesture_seen_pairs and len(gesture_recommendations) < MAX_GESTURE_RECOMMEND:
                gesture_seen_pairs.add(pair)
                gesture_recommendations.append({
                    "device": device,
                    "recommended_gesture": gesture,
                    "reason": reason
                })

        def add_gesture_sequence(target_device, gesture, reason):
            if current_device != target_device:
                mode_gesture = mode_gestures.get(target_device)
                if mode_gesture and (target_device, mode_gesture) not in gesture_seen_pairs:
                    add_gesture_recommendation(target_device, mode_gesture, f"{target_device} 모드 진입을 추천해요!")
            add_gesture_recommendation(target_device, gesture, reason)

        def add_voice_recommendation(device, voice, reason):
            doc = firestore_db.collection("voice_list").document(voice).get()
            description = doc.to_dict().get("description") if doc.exists else voice

            pair = (device, voice)
            if pair not in voice_seen_pairs and len(voice_recommendations) < MAX_VOICE_RECOMMEND:
                voice_seen_pairs.add(pair)
                voice_recommendations.append({
                    "device": device,
                    "recommended_voice": description,
                    "reason": reason
                })

        def add_voice_sequence(target_device, pred_voice, reason):
            if (target_device, pred_voice) in voice_seen_pairs:
                return

            pred_device = pred_voice.split("_")[0]
            if pred_device == target_device:
                add_voice_recommendation(target_device, pred_voice, reason)

        # 규칙 기반 추천
        rule_conditions = [
            ("fan", temp > 27, "현재 온도가 높음 (>27°C) 및 전원이 꺼짐"), 
            ("curtain", is_morning, "아침 시간대 커튼 열기"), 
            ("light", is_evening, "저녁 시간대 전등 켜기")
        ]

        for device, condition, reason in rule_conditions:
            if condition and status_refs.get(device, {}).get("power") != "on":
                power_gesture = power_gestures.get(device)
                if power_gesture:
                    add_gesture_sequence(device, power_gesture, reason)
                    add_voice_sequence(device, f"{device}_on", reason)

        # 모델 로드
        user_model_dir = os.path.join(MODEL_DIR, uid)
        gesture_model, gesture_encoder = None, None
        voice_model, voice_encoder = None, None

        gesture_model_path = os.path.join(user_model_dir, "gesture_model.pkl")
        gesture_encoder_path = os.path.join(user_model_dir, "gesture_encoder.pkl")
        if os.path.exists(gesture_model_path) and os.path.exists(gesture_encoder_path):
            gesture_model = joblib.load(gesture_model_path)
            gesture_encoder = joblib.load(gesture_encoder_path)

        voice_model_path = os.path.join(user_model_dir, "voice_model.pkl")
        voice_encoder_path = os.path.join(user_model_dir, "voice_encoder.pkl")
        if os.path.exists(voice_model_path) and os.path.exists(voice_encoder_path):
            voice_model = joblib.load(voice_model_path)
            voice_encoder = joblib.load(voice_encoder_path)

        # 로그 기반 추천
        for device in mode_gestures:
            status = status_refs[device]
            log = status.get("log", {})
            power = status.get("power", "unknown")
            fan_mode = log.get("fan_mode", "unknown")
            wind_power = log.get("wind_power", "unknown")
            color = log.get("color", "unknown")

            X_input = [hour, weekday, temp, device, power, fan_mode, wind_power, color]

            if gesture_model:
                X_gesture = gesture_encoder.transform([X_input]).toarray()
                pred_gesture = gesture_model.predict(X_gesture)[0]
                add_gesture_sequence(device, pred_gesture, "당신의 생활패턴에 딱 맞는 제스처 추천입니다.")

            if voice_model:
                X_voice = voice_encoder.transform([X_input]).toarray()
                pred_voice = voice_model.predict(X_voice)[0]
                add_voice_sequence(device, pred_voice, "당신의 생활패턴에 딱 맞는 음성 추천입니다.")

        if not (gesture_recommendations or voice_recommendations):
            return jsonify({"message": "추천할 제스처와 음성이 없습니다."})

        return jsonify({
            "timestamp": now.isoformat(),
            "recommendations": gesture_recommendations + voice_recommendations
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


def extract_features(log_entry):
    try:
        createdAt = log_entry["createdAt"]
        dt = datetime.fromisoformat(createdAt)
        hour = dt.hour
        weekday = dt.weekday()
        temp = float(log_entry.get("temperature", 24.0))
        return {
            "hour": hour,
            "weekday": weekday,
            "temperature": temp,
            "device": log_entry.get("device", "unknown"),
            "power": log_entry.get("power", "unknown"),
            "fan_mode": log_entry.get("fan_mode", "unknown"),
            "wind_power": log_entry.get("wind_power", "unknown"),
            "color": log_entry.get("color", "unknown"),
            "gesture": log_entry.get("gesture"), 
            "voice" : log_entry.get("voice")
        }
    except:
        return None


def train_model():
    firestore_db = firestore.client()
    users_ref = firestore_db.collection("users")
    users = users_ref.stream()

    for doc in users:
        uid = doc.id
        logs = users_ref.document(uid).collection("logs").stream()
        
        gesture_dataset = []
        voice_dataset = []

        for log_doc in logs:
            entry = log_doc.to_dict()
            features = extract_features(entry)
            if features:
                if features.get("gesture"):
                    gesture_dataset.append(features)
                if features.get("voice"):
                    voice_dataset.append(features)                    

        if not gesture_dataset:
            print(f"{uid} - 학습할 제스처 데이터가 없습니다.")
            continue

        if not voice_dataset:
            print(f"{uid} - 학습할 음성 데이터가 없습니다.")
            continue

        user_model_dir = os.path.join(MODEL_DIR, uid)
        os.makedirs(user_model_dir, exist_ok=True)

        # gesture model 학습
        if gesture_dataset:
            X_raw = [{k: v for k, v in d.items() if k != "gesture"} for d in gesture_dataset]
            y = [d["gesture"] for d in gesture_dataset]

            encoder = OneHotEncoder(handle_unknown="ignore")
            X_encoded = encoder.fit_transform([
                [
                    d["hour"], d["weekday"], d["temperature"], d["device"],
                    d["power"], d["fan_mode"], d["wind_power"], d["color"]
                ] for d in X_raw
            ]).toarray()

            model = RandomForestClassifier(n_estimators=100, random_state=42)
            model.fit(X_encoded, y)

            joblib.dump(model, os.path.join(user_model_dir, "gesture_model.pkl"))
            joblib.dump(encoder, os.path.join(user_model_dir, "gesture_encoder.pkl"))

            print(f"{uid} - 제스처 모델 학습 및 저장 완료")

        # voice model 학습
        if voice_dataset:
            X_raw = [{k: v for k, v in d.items() if k != "voice"} for d in voice_dataset]
            y = [d["voice"] for d in voice_dataset]

            encoder = OneHotEncoder(handle_unknown="ignore")
            X_encoded = encoder.fit_transform([
                [
                    d["hour"], d["weekday"], d["temperature"], d["device"],
                    d["power"], d["fan_mode"], d["wind_power"], d["color"]
                ] for d in X_raw
            ]).toarray()

            model = RandomForestClassifier(n_estimators=100, random_state=42)
            model.fit(X_encoded, y)

            joblib.dump(model, os.path.join(user_model_dir, "voice_model.pkl"))
            joblib.dump(encoder, os.path.join(user_model_dir, "voice_encoder.pkl"))

            print(f"{uid} - 음성 모델 학습 및 저장 완료")
