from app import create_app
from flasgger import Swagger
from app.routes.auto_train import start_scheduler
import threading

app = create_app()

swagger = Swagger(app, config={
    "headers": [],
    "specs": [
        {
            "endpoint": 'apispec_1',
            "route": '/apispec_1.json',
            "rule_filter": lambda rule: True,
            "model_filter": lambda tag: True,
        }
    ],
    "static_url_path": "/flasgger_static",
    "swagger_ui": True,
    "specs_route": "/apidocs/",
    "basePath": "/",
})

# -----------------------
#        서버 실행
# -----------------------
if __name__ == "__main__":
    # 백그라운드 스레드에서 스케줄러 실행
    scheduler_thread = threading.Thread(target=start_scheduler)
    scheduler_thread.daemon = True  # Flask 종료 시 함께 종료됨
    scheduler_thread.start()

    app.run(host="0.0.0.0", port=5000, debug=True)
