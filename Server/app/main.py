from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
from app.routers import game

app = FastAPI()

app.include_router(game.router)
