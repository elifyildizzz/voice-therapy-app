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
vocal_hygiene_responses_collection = database["vocal_hygiene_responses"]
client_form_records_collection = database["client_form_records"]
sz_test_records_collection = database["sz_test_records"]
notification_profiles_collection = database["notification_profiles"]
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
    current_password: str | None = None
    new_password: str | None = Field(default=None, min_length=8)


class VocalHygieneResponseCreate(BaseModel):
    answers: dict[str, list[str]]


class ClientFormResponses(BaseModel):
    vrqol_q1: int = Field(ge=1, le=5)
    vrqol_q4: int = Field(ge=1, le=5)
    vrqol_q9: int = Field(ge=1, le=5)
    vhi_q3: int = Field(ge=1, le=5)
    vhi_q9: int = Field(ge=1, le=5)


class ClientFormRecordCreate(BaseModel):
    responses: ClientFormResponses


class SzTestRecordCreate(BaseModel):
    s_attempts: list[float] = Field(min_length=1)
    z_attempts: list[float] = Field(min_length=1)


class NotificationProfileUpdate(BaseModel):
    vocal_hygiene_enabled: bool | None = None
    max_daily_notifications: int | None = Field(default=None, ge=1, le=3)
    preferred_times: list[str] | None = None
    quiet_hours: dict[str, str] | None = None
    enabled_topics: list[str] | None = None


@app.on_event("startup")
async def startup() -> None:
    await mongo_client.admin.command("ping")
    collection_names = await database.list_collection_names()
    for collection_name in (
        "users",
        "vocal_hygiene_responses",
        "client_form_records",
        "sz_test_records",
        "notification_profiles",
    ):
        if collection_name not in collection_names:
            await database.create_collection(collection_name)
    await users_collection.create_index("email", unique=True)
    await vocal_hygiene_responses_collection.create_index(
        [("user_id", 1), ("created_at", -1)]
    )
    await client_form_records_collection.create_index(
        [("user_id", 1), ("created_at", -1)]
    )
    await sz_test_records_collection.create_index(
        [("user_id", 1), ("created_at", -1)]
    )
    await notification_profiles_collection.create_index("user_id", unique=True)


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


def _serialize_object_id(value: ObjectId | str) -> str:
    return str(value)


def _serialize_vocal_hygiene_response(document: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": _serialize_object_id(document["_id"]),
        "user_id": _serialize_object_id(document["user_id"]),
        "answers": document["answers"],
        "topic_scores": document.get("topic_scores", {}),
        "primary_topics": document.get("primary_topics", []),
        "questionnaire_version": document.get("questionnaire_version", 1),
        "created_at": _serialize_datetime(document["created_at"]),
    }


def _serialize_client_form_record(document: dict[str, Any]) -> dict[str, Any]:
    responses = document["responses"]
    return {
        "id": _serialize_object_id(document["_id"]),
        "user_id": _serialize_object_id(document["user_id"]),
        "created_at": _serialize_datetime(document["created_at"]),
        "responses": responses,
        "vrqol_q1": responses["vrqol_q1"],
        "vrqol_q4": responses["vrqol_q4"],
        "vrqol_q9": responses["vrqol_q9"],
        "vhi_q3": responses["vhi_q3"],
        "vhi_q9": responses["vhi_q9"],
        "total_score": document["total_score"],
        "result_label": document["result_label"],
        "form_version": document.get("form_version", 1),
    }


def _serialize_sz_test_record(document: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": _serialize_object_id(document["_id"]),
        "user_id": _serialize_object_id(document["user_id"]),
        "created_at": _serialize_datetime(document["created_at"]),
        "s_attempts": document["s_attempts"],
        "z_attempts": document["z_attempts"],
        "s_best": document["s_best"],
        "z_best": document["z_best"],
        "ratio": document["ratio"],
    }


def _serialize_notification_profile(document: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": _serialize_object_id(document["_id"]),
        "user_id": _serialize_object_id(document["user_id"]),
        "vocal_hygiene_enabled": document.get("vocal_hygiene_enabled", True),
        "max_daily_notifications": document.get("max_daily_notifications", 2),
        "preferred_times": document.get("preferred_times", ["10:30", "15:30"]),
        "quiet_hours": document.get("quiet_hours", {"start": "22:00", "end": "09:00"}),
        "enabled_topics": document.get("enabled_topics", _notification_topics()),
        "active_plan": _serialize_notification_plan(document.get("active_plan")),
        "created_at": _serialize_datetime(document["created_at"]),
        "updated_at": _serialize_datetime(document["updated_at"]),
    }


def _serialize_notification_plan(plan: dict[str, Any] | None) -> dict[str, Any] | None:
    if plan is None:
        return None

    serialized = dict(plan)
    for key in ("generated_at", "updated_at"):
        if isinstance(serialized.get(key), datetime):
            serialized[key] = _serialize_datetime(serialized[key])
    return serialized


def _calculate_client_form_total_score(responses: dict[str, int]) -> int:
    return (
        responses["vrqol_q1"]
        + responses["vrqol_q4"]
        + responses["vrqol_q9"]
        + responses["vhi_q3"]
        + responses["vhi_q9"]
    )


def _resolve_client_form_result_label(total_score: int) -> str:
    if total_score <= 4:
        return "Düşük düzeyde etkilenim"
    if total_score <= 9:
        return "Hafif düzeyde etkilenim"
    if total_score <= 14:
        return "Orta düzeyde etkilenim"
    return "Yüksek düzeyde etkilenim"


def _calculate_vocal_hygiene_topics(
    answers: dict[str, list[str]],
) -> tuple[dict[str, int], list[str]]:
    default_order = [
        "hydration",
        "nutrition",
        "voice_usage",
        "environmental_factors",
        "irritants",
        "voice_rest",
        "throat_clearing",
        "reflux_control",
    ]
    scores = {topic: 0 for topic in default_order}

    def add(topic: str, points: int) -> None:
        scores[topic] = scores.get(topic, 0) + points

    def single(question_id: str) -> str | None:
        selected = answers.get(question_id, [])
        return selected[0] if selected else None

    if single("water") == "0_1":
        add("hydration", 4)
        add("nutrition", 1)
    elif single("water") == "1_2":
        add("hydration", 2)

    if single("voice_usage") == "high":
        add("voice_usage", 3)
        add("voice_rest", 2)
    elif single("voice_usage") == "medium":
        add("voice_usage", 1)

    if single("noisy_env") == "often":
        add("voice_usage", 2)
        add("voice_rest", 2)
        add("environmental_factors", 2)
    elif single("noisy_env") == "sometimes":
        add("voice_usage", 1)
        add("voice_rest", 1)
        add("environmental_factors", 1)

    symptoms = set(answers.get("symptoms", []))
    if "dryness" in symptoms:
        add("throat_clearing", 2)
        add("hydration", 1)
    if "hoarseness" in symptoms:
        add("voice_rest", 2)
        add("voice_usage", 1)
    if "fatigue" in symptoms:
        add("voice_rest", 3)
    if "burning" in symptoms:
        add("reflux_control", 1)
        add("irritants", 1)
    if "morning_worse" in symptoms:
        add("reflux_control", 2)

    if single("throat_clearing") == "often":
        add("throat_clearing", 3)
        add("voice_rest", 1)
    elif single("throat_clearing") == "sometimes":
        add("throat_clearing", 1)

    if single("caffeine") == "3_plus":
        add("irritants", 3)
        add("nutrition", 1)
    elif single("caffeine") == "1_2":
        add("irritants", 1)
        add("nutrition", 1)

    if single("smoke") == "often":
        add("irritants", 3)
        add("environmental_factors", 2)
    elif single("smoke") == "sometimes":
        add("irritants", 1)
        add("environmental_factors", 1)

    if single("talking_time") == "high":
        add("voice_usage", 2)
        add("voice_rest", 1)
    elif single("talking_time") == "medium":
        add("voice_usage", 1)

    if single("reflux") == "often":
        add("reflux_control", 4)
    elif single("reflux") == "sometimes":
        add("reflux_control", 2)

    ordered_topics = sorted(
        default_order,
        key=lambda topic: (-scores.get(topic, 0), default_order.index(topic)),
    )
    primary_topics = [
        topic for topic in ordered_topics[:2] if scores.get(topic, 0) >= 4
    ]
    return scores, primary_topics


def _notification_topics() -> list[str]:
    return [
        "hydration",
        "nutrition",
        "voice_usage",
        "environmental_factors",
        "irritants",
        "voice_rest",
        "throat_clearing",
        "reflux_control",
    ]


def _default_notification_profile(user_id: ObjectId, now: datetime) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "vocal_hygiene_enabled": True,
        "max_daily_notifications": 2,
        "preferred_times": ["10:30", "15:30"],
        "quiet_hours": {"start": "22:00", "end": "09:00"},
        "enabled_topics": _notification_topics(),
        "active_plan": None,
        "created_at": now,
        "updated_at": now,
    }


def _notification_message_catalog() -> dict[str, dict[str, str]]:
    return {
        "hydration": {
            "title": "Su molası",
            "body": (
                "Ses sağlığın için küçük bir su molası ver. Bir bardak su "
                "boğaz kuruluğunu azaltmaya yardımcı olabilir."
            ),
        },
        "nutrition": {
            "title": "Ses dostu seçim",
            "body": (
                "Bugün çok sıcak, çok soğuk veya boğazını kurutabilecek "
                "seçimleri biraz azaltmayı deneyebilirsin."
            ),
        },
        "voice_usage": {
            "title": "Sesini yumuşat",
            "body": (
                "Bugün sesini yoğun kullanıyor olabilirsin. Daha yakın "
                "mesafeden ve daha yumuşak konuşmayı dene."
            ),
        },
        "environmental_factors": {
            "title": "Ortamı fark et",
            "body": (
                "Gürültülü ortamda sesini yükseltmek yerine kısa molalar "
                "vermeyi ve mümkünse ortamı sakinleştirmeyi dene."
            ),
        },
        "irritants": {
            "title": "Boğazını koru",
            "body": (
                "Kafein ve duman boğaz kuruluğunu artırabilir. Bugün yanında "
                "su bulundurmayı unutma."
            ),
        },
        "voice_rest": {
            "title": "Ses molası zamanı",
            "body": (
                "Ses yorgunluğu hissediyorsan 5 dakikalık sessiz bir mola "
                "ses tellerinin toparlanmasına destek olur."
            ),
        },
        "throat_clearing": {
            "title": "Nazik bir alternatif",
            "body": (
                "Boğazını sertçe temizlemek yerine küçük bir yudum su almayı "
                "veya nazikçe yutkunmayı dene."
            ),
        },
        "reflux_control": {
            "title": "Akşam rahatlığı",
            "body": (
                "Reflü hassasiyeti için akşam geç saatte ağır yiyeceklerden "
                "kaçınmak ses konforunu destekleyebilir."
            ),
        },
    }


def _build_vocal_hygiene_notification_plan(
    *,
    source_response_id: ObjectId,
    topic_scores: dict[str, int],
    primary_topics: list[str],
    profile: dict[str, Any],
    now: datetime,
) -> dict[str, Any] | None:
    if not profile.get("vocal_hygiene_enabled", True):
        return None

    enabled_topics = set(profile.get("enabled_topics") or _notification_topics())
    scored_topics = [
        topic
        for topic, score in sorted(
            topic_scores.items(),
            key=lambda item: (-item[1], _notification_topics().index(item[0])),
        )
        if score > 0 and topic in enabled_topics
    ]
    ordered_topics = []
    for topic in [*primary_topics, *scored_topics]:
        if topic not in ordered_topics:
            ordered_topics.append(topic)

    max_daily = int(profile.get("max_daily_notifications", 2))
    selected_topics = ordered_topics[:max_daily]
    if not selected_topics:
        return None

    preferred_times = profile.get("preferred_times") or ["10:30", "15:30"]
    catalog = _notification_message_catalog()
    items = []
    for index, topic in enumerate(selected_topics):
        message = catalog[topic]
        items.append(
            {
                "notification_id": f"vocal_hygiene_{topic}_{index + 1}",
                "topic": topic,
                "title": message["title"],
                "body": message["body"],
                "time": preferred_times[index % len(preferred_times)],
                "repeat": "daily",
            }
        )

    return {
        "plan_id": str(ObjectId()),
        "source": "vocal_hygiene",
        "source_response_id": str(source_response_id),
        "status": "active",
        "topics": selected_topics,
        "items": items,
        "generated_at": now,
        "updated_at": now,
    }


async def _get_or_create_notification_profile(user_id: ObjectId) -> dict[str, Any]:
    document = await notification_profiles_collection.find_one({"user_id": user_id})
    if document is not None:
        return document

    now = _utc_now()
    document = _default_notification_profile(user_id, now)
    result = await notification_profiles_collection.insert_one(document)
    document["_id"] = result.inserted_id
    return document


async def _refresh_vocal_hygiene_notification_profile(
    *,
    user_id: ObjectId,
    source_response_id: ObjectId,
    topic_scores: dict[str, int],
    primary_topics: list[str],
) -> dict[str, Any]:
    profile = await _get_or_create_notification_profile(user_id)
    now = _utc_now()
    active_plan = _build_vocal_hygiene_notification_plan(
        source_response_id=source_response_id,
        topic_scores=topic_scores,
        primary_topics=primary_topics,
        profile=profile,
        now=now,
    )

    await notification_profiles_collection.update_one(
        {"_id": profile["_id"]},
        {
            "$set": {
                "active_plan": active_plan,
                "updated_at": now,
            }
        },
    )
    profile["active_plan"] = active_plan
    profile["updated_at"] = now
    return profile


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

    update_fields = {
        "email": normalized_email,
        "first_name": clean_first_name,
        "last_name": clean_last_name,
        "updated_at": _utc_now(),
    }
    if payload.new_password:
        if not payload.current_password or not password_context.verify(
            payload.current_password,
            current_user["password_hash"],
        ):
            raise HTTPException(
                status_code=401,
                detail="Mevcut şifre hatalı.",
            )
        _validate_password_for_bcrypt(payload.new_password)
        update_fields["password_hash"] = password_context.hash(payload.new_password)

    await users_collection.update_one(
        {"_id": current_user["_id"]},
        {"$set": update_fields},
    )
    updated_user = await users_collection.find_one({"_id": current_user["_id"]})
    return {"user": _serialize_user(updated_user)}


@app.post("/vocal-hygiene/responses", status_code=201)
async def create_vocal_hygiene_response(
    payload: VocalHygieneResponseCreate,
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    clean_answers = {
        question_id: [str(option_id) for option_id in selected]
        for question_id, selected in payload.answers.items()
    }
    if not clean_answers:
        raise HTTPException(status_code=422, detail="En az bir cevap gereklidir.")

    topic_scores, primary_topics = _calculate_vocal_hygiene_topics(clean_answers)
    document = {
        "user_id": current_user["_id"],
        "answers": clean_answers,
        "topic_scores": topic_scores,
        "primary_topics": primary_topics,
        "questionnaire_version": 1,
        "created_at": _utc_now(),
    }
    result = await vocal_hygiene_responses_collection.insert_one(document)
    document["_id"] = result.inserted_id
    notification_profile = await _refresh_vocal_hygiene_notification_profile(
        user_id=current_user["_id"],
        source_response_id=document["_id"],
        topic_scores=topic_scores,
        primary_topics=primary_topics,
    )
    return {
        "response": _serialize_vocal_hygiene_response(document),
        "notification_profile": _serialize_notification_profile(notification_profile),
        "notification_plan": _serialize_notification_plan(
            notification_profile.get("active_plan")
        ),
    }


@app.get("/vocal-hygiene/responses/latest")
async def latest_vocal_hygiene_response(
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    document = await vocal_hygiene_responses_collection.find_one(
        {"user_id": current_user["_id"]},
        sort=[("created_at", -1)],
    )
    return {
        "response": (
            _serialize_vocal_hygiene_response(document)
            if document is not None
            else None
        )
    }


@app.get("/vocal-hygiene/responses")
async def list_vocal_hygiene_responses(
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    cursor = vocal_hygiene_responses_collection.find(
        {"user_id": current_user["_id"]}
    ).sort("created_at", -1)
    documents = await cursor.to_list(length=100)
    return {
        "responses": [
            _serialize_vocal_hygiene_response(document) for document in documents
        ]
    }


@app.get("/notification-profile/me")
async def get_notification_profile(
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    profile = await _get_or_create_notification_profile(current_user["_id"])
    return {"notification_profile": _serialize_notification_profile(profile)}


@app.patch("/notification-profile/me")
async def update_notification_profile(
    payload: NotificationProfileUpdate,
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    profile = await _get_or_create_notification_profile(current_user["_id"])
    updates = {
        key: value
        for key, value in payload.dict(exclude_unset=True).items()
        if value is not None
    }

    if "enabled_topics" in updates:
        allowed_topics = set(_notification_topics())
        invalid_topics = [
            topic for topic in updates["enabled_topics"] if topic not in allowed_topics
        ]
        if invalid_topics:
            raise HTTPException(
                status_code=422,
                detail=f"Geçersiz bildirim konusu: {', '.join(invalid_topics)}",
            )

    active_plan = profile.get("active_plan")
    if updates.get("vocal_hygiene_enabled") is False:
        active_plan = None
    elif active_plan is not None:
        if "enabled_topics" in updates:
            enabled_topics = set(updates["enabled_topics"])
            active_plan["items"] = [
                item
                for item in active_plan.get("items", [])
                if item.get("topic") in enabled_topics
            ]
            active_plan["topics"] = [
                topic for topic in active_plan.get("topics", []) if topic in enabled_topics
            ]
        if "max_daily_notifications" in updates:
            max_daily = int(updates["max_daily_notifications"])
            active_plan["items"] = active_plan.get("items", [])[:max_daily]
            active_plan["topics"] = active_plan.get("topics", [])[:max_daily]
        if "preferred_times" in updates and updates["preferred_times"]:
            preferred_times = updates["preferred_times"]
            for index, item in enumerate(active_plan.get("items", [])):
                item["time"] = preferred_times[index % len(preferred_times)]
        if not active_plan.get("items"):
            active_plan = None
        else:
            active_plan["updated_at"] = _utc_now()

    updates["active_plan"] = active_plan
    updates["updated_at"] = _utc_now()
    await notification_profiles_collection.update_one(
        {"_id": profile["_id"]},
        {"$set": updates},
    )
    updated_profile = await notification_profiles_collection.find_one(
        {"_id": profile["_id"]}
    )
    return {"notification_profile": _serialize_notification_profile(updated_profile)}


@app.post("/client-form-records", status_code=201)
async def create_client_form_record(
    payload: ClientFormRecordCreate,
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    responses = payload.responses.dict()
    total_score = _calculate_client_form_total_score(responses)
    document = {
        "user_id": current_user["_id"],
        "responses": responses,
        "total_score": total_score,
        "result_label": _resolve_client_form_result_label(total_score),
        "form_version": 1,
        "created_at": _utc_now(),
    }
    result = await client_form_records_collection.insert_one(document)
    document["_id"] = result.inserted_id
    return {"record": _serialize_client_form_record(document)}


@app.get("/client-form-records/latest")
async def latest_client_form_record(
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    document = await client_form_records_collection.find_one(
        {"user_id": current_user["_id"]},
        sort=[("created_at", -1)],
    )
    return {
        "record": (
            _serialize_client_form_record(document) if document is not None else None
        )
    }


@app.get("/client-form-records")
async def list_client_form_records(
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    cursor = client_form_records_collection.find(
        {"user_id": current_user["_id"]}
    ).sort("created_at", -1)
    documents = await cursor.to_list(length=100)
    return {"records": [_serialize_client_form_record(document) for document in documents]}


@app.post("/sz-test-records", status_code=201)
async def create_sz_test_record(
    payload: SzTestRecordCreate,
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    s_attempts = [float(value) for value in payload.s_attempts]
    z_attempts = [float(value) for value in payload.z_attempts]
    if any(value < 0 for value in [*s_attempts, *z_attempts]):
        raise HTTPException(status_code=422, detail="Süre değerleri negatif olamaz.")

    s_best = max(s_attempts)
    z_best = max(z_attempts)
    ratio = 0.0 if z_best == 0 else s_best / z_best
    document = {
        "user_id": current_user["_id"],
        "s_attempts": s_attempts,
        "z_attempts": z_attempts,
        "s_best": s_best,
        "z_best": z_best,
        "ratio": ratio,
        "created_at": _utc_now(),
    }
    result = await sz_test_records_collection.insert_one(document)
    document["_id"] = result.inserted_id
    return {"record": _serialize_sz_test_record(document)}


@app.get("/sz-test-records/latest")
async def latest_sz_test_record(
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    document = await sz_test_records_collection.find_one(
        {"user_id": current_user["_id"]},
        sort=[("created_at", -1)],
    )
    return {
        "record": _serialize_sz_test_record(document) if document is not None else None
    }


@app.get("/sz-test-records")
async def list_sz_test_records(
    current_user: dict[str, Any] = Depends(_get_current_user),
) -> dict[str, Any]:
    cursor = sz_test_records_collection.find({"user_id": current_user["_id"]}).sort(
        "created_at", -1
    )
    documents = await cursor.to_list(length=100)
    return {"records": [_serialize_sz_test_record(document) for document in documents]}


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
