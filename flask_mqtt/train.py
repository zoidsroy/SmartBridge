from app import create_app
from app.routes.recommand import train_model

if __name__ == "__main__":
    app = create_app()

    with app.app_context():
        train_model()