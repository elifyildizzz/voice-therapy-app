from fastapi import FastAPI, File, HTTPException, UploadFile

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
