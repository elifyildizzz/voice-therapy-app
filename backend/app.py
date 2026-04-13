from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile

try:
    from backend.voice_screening_inference import AudioQualityError, analyze_voice_pair
except ModuleNotFoundError:
    from voice_screening_inference import AudioQualityError, analyze_voice_pair

app = FastAPI(title="Voice Therapy Backend", version="1.0.0")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


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
