from fastapi.middleware.cors import CORSMiddleware

origins = [
    "http://localhost",
]


def add_cors_middleware(app) -> object:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
