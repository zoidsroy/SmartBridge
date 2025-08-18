from flask import Flask
from flask_cors import CORS
from firebase_admin import credentials, initialize_app, firestore
from .config import Config
from flasgger import Swagger

def create_app():
    app = Flask(__name__)
    #Swagger(app)
    app.config.from_object(Config)

    CORS(app)

    # firebase admin 초기화 (RTDB용)
    cred = credentials.Certificate("firebase_config.json")
    initialize_app(cred, {'databaseURL' : app.config['FIREBASE_DB_URL']})

    # firestore 초기화
    firestore_db = firestore.client()
    app.config['FIRESTORE_DB'] = firestore_db

    from app.routes.gesture import gesture_bp
    from app.routes.voice import voice_bp
    from app.routes.status import status_bp
    from app.routes.dashboard import dashboard_bp
    from app.routes.recommand import recommand_bp
    from app.routes.ircode import ircode_bp

    app.register_blueprint(gesture_bp)
    app.register_blueprint(voice_bp)
    app.register_blueprint(status_bp)
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(recommand_bp)
    app.register_blueprint(ircode_bp)

    return app
