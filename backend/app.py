from __future__ import annotations

import os
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from bson import ObjectId
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from jose import JWTError, jwt
from motor.motor_asyncio import AsyncIOMotorClient
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, Field
from pymongo.errors import DuplicateKeyError

try:
    from backend.voice_screening_inference import AudioQualityError, analyze_voice_pair
except ModuleNotFoundError as exc:
    if exc.name not in {"backend", "backend.voice_screening_inference"}:
        raise
    from voice_screening_inference import AudioQualityError, analyze_voice_pair

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB_NAME = os.getenv("MONGODB_DB_NAME", "voice_therapy")
JWT_SECRET = os.getenv("JWT_SECRET", "voice-therapy-dev-secret-change-me")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(
    os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", str(60 * 24 * 30))
)

mongo_client = AsyncIOMotorClient(MONGODB_URI)
database = mongo_client[MONGODB_DB_NAME]
users_collection = database["users"]
password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

app = FastAPI(title="Voice Therapy Backend", version="1.0.0")


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class UpdateProfileRequest(BaseModel):
    email: EmailStr
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)


@app.on_event("startup")
async def startup() -> None:
    await mongo_client.admin.command("ping")
    collection_names = await database.list_collection_names()
    if "users" not in collection_names:
        await database.create_collection("users")
    await users_collection.create_index("email", unique=True)


@app.on_event("shutdown")
async def shutdown() -> None:
    mongo_client.close()


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "database": MONGODB_DB_NAME}


@app.post("/auth/register", status_code=201)
async def register(payload: RegisterRequest) -> dict[str, Any]:
    normalized_email = payload.email.strip().lower()
    clean_first_name = payload.first_name.strip()
    clean_last_name = payload.last_name.strip()
    _validate_password_for_bcrypt(payload.password)

    if not clean_first_name or not clean_last_name:
        raise HTTPException(
            status_code=422,
            detail="Ad ve soyad alanları boş bırakılamaz.",
        )

    now = _utc_now()
    user_document = {
        "email": normalized_email,
        "password_hash": password_context.hash(payload.password),
        "first_name": clean_first_name,
        "last_name": clean_last_name,
        "created_at": now,
        "updated_at": now,
    }

    try:
        result = await users_collection.insert_one(user_document)
    except DuplicateKeyError as exc:
        raise HTTPException(
            status_code=409,
            detail="Bu e-posta ile kayıtlı bir hesap zaten var.",
        ) from exc

    user_document["_id"] = result.inserted_id
    return {"user": _serialize_user(user_document)}


def _validate_password_for_bcrypt(password: str) -> None:
    if len(password.encode("utf-8")) > 72:
        raise HTTPException(
            status_code=422,
            detail="Şifre en fazla 72 byte uzunluğunda olabilir.",
        )


@app.post("/auth/login")
async def login(payload: LoginRequest) -> dict[str, Any]:
    normalized_email = payload.email.strip().lower()
    user_document = await users_collection.find_one({"email": normalized_email})

    if user_document is None or not password_context.verify(
        payload.password,
        user_document["password_hash"],
    ):
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı.")

    token = _create_access_token(subject=str(user_document["_id"]))
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": _serialize_user(user_document),
    }


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _create_access_token(subject: str) -> str:
    expires_at = _utc_now() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": subject, "exp": expires_at}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


async def _get_current_user(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    credentials_exception = HTTPException(
        status_code=401,
        detail="Oturum geçersiz veya süresi dolmuş.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if authorization is None:
        raise credentials_exception

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise credentials_exception

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("sub")
    except JWTError as exc:
        raise credentials_exception from exc

    if not isinstance(user_id, str) or not ObjectId.is_valid(user_id):
        raise credentials_exception

    user_document = await users_collection.find_one({"_id": ObjectId(user_id)})
    if user_document is None:
        raise credentials_exception

    return user_document


def _serialize_user(user_document: dict[str, Any] | None) -> dict[str, Any]:
    if user_document is None:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")

    return {
        "id": str(user_document["_id"]),
        "email": user_document["email"],
        "first_name": user_document["first_name"],
        "last_name": user_document["last_name"],
        "created_at": _serialize_datetime(user_document["created_at"]),
    }


def _serialize_datetime(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


@app.get("/auth/me")
async def me(current_user: dict[str, Any] = Depends(_get_current_user)) -> dict:
    return {"user": _serialize_user(current_user)}


@app.patch("/auth/me")
async def update_me(
    payload: UpdateProfileRequest,
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict:
    normalized_email = payload.email.strip().lower()
    clean_first_name = payload.first_name.strip()
    clean_last_name = payload.last_name.strip()

    if not clean_first_name or not clean_last_name:
        raise HTTPException(
            status_code=422,
            detail="Ad ve soyad alanları boş bırakılamaz.",
        )

    existing_user = await users_collection.find_one({"email": normalized_email})
    if existing_user is not None and existing_user["_id"] != current_user["_id"]:
        raise HTTPException(
            status_code=409,
            detail="Bu e-posta ile kayıtlı bir hesap zaten var.",
        )

    await users_collection.update_one(
        {"_id": current_user["_id"]},
        {
            "$set": {
                "email": normalized_email,
                "first_name": clean_first_name,
                "last_name": clean_last_name,
                "updated_at": _utc_now(),
            }
        },
    )
    updated_user = await users_collection.find_one({"_id": current_user["_id"]})
    return {"user": _serialize_user(updated_user)}


@app.post("/analyze-voice")
async def analyze_voice(file: UploadFile = File(...)) -> dict:
    if not file.filename:
        raise HTTPException(status_code=400, detail="Dosya adı boş olamaz.")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Boş dosya gönderildi.")

    return {
        "success": True,
        "filename": file.filename,
        "content_type": file.content_type,
        "size_bytes": len(content),
        "analysis": {
            "status": "received",
            "label": "unknown",
            "message": "Dosya alındı. ML analizi henüz entegre değil.",
        },
    }


async def _write_upload_to_temp_file(upload: UploadFile, suffix: str) -> Path:
    content = await upload.read()
    if not content:
        raise HTTPException(status_code=400, detail="Boş dosya gönderildi.")

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
        temp_file.write(content)
        return Path(temp_file.name)


@app.post("/analyze-voice-screening")
async def analyze_voice_screening(
    a_file: UploadFile = File(...),
    i_file: UploadFile = File(...),
) -> dict:
    if not a_file.filename or not i_file.filename:
        raise HTTPException(status_code=400, detail="Dosya adı boş olamaz.")

    a_temp_path: Path | None = None
    i_temp_path: Path | None = None

    try:
        a_temp_path = await _write_upload_to_temp_file(a_file, suffix=".wav")
        i_temp_path = await _write_upload_to_temp_file(i_file, suffix=".wav")
        return analyze_voice_pair(a_temp_path, i_temp_path)
    except HTTPException:
        raise
    except AudioQualityError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Ses dosyası işlenemedi: {exc}",
        ) from exc
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Ön tarama analizi sırasında hata oluştu: {exc}",
        ) from exc
    finally:
        for temp_path in (a_temp_path, i_temp_path):
            if temp_path is not None and temp_path.exists():
                temp_path.unlink(missing_ok=True)
