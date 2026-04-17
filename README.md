# Voice Therapy App

Bu repo, ses terapisi uygulamasinin mobil istemcisini ve Python tabanli backend servisini icerir.

## Proje Yapisi

- `mobile/`: Flutter mobil uygulamasi
- `backend/`: FastAPI backend servisi
- `ml/`: model egitimi ve veri isleme scriptleri
- `docs/`: ek dokumantasyon

## Gereksinimler

- Flutter SDK
- Dart SDK
- Python 3.10+
- MongoDB

## Ortam Degiskenleri

Kok dizinde bir `.env` dosyasi bekleniyor. Ornek dosyayi kopyalayip doldurabilirsiniz:

```bash
cp .env.example .env
```

En kritik alanlar:

- `MONGODB_URI`
- `MONGODB_DB_NAME`
- `JWT_SECRET`

## Backend Nasil Calistirilir

1. Backend klasorune girin:

```bash
cd backend
```

2. Sanal ortam olusturun ve aktif edin:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

3. Paketleri yukleyin:

```bash
pip install -r requirements.txt
```

4. API'yi baslatin:

```bash
uvicorn app:app --reload
```

Backend varsayilan olarak `http://127.0.0.1:8000` adresinde calisir.

Saglik kontrolu icin:

```bash
curl http://127.0.0.1:8000/health
```

## Mobile Nasil Calistirilir

1. Mobil klasore girin:

```bash
cd mobile
```

2. Paketleri yukleyin:

```bash
flutter pub get
```

3. Bagli cihazlari kontrol edin:

```bash
flutter devices
```

4. Uygulamayi calistirin:

```bash
flutter run
```

## Mobile-Backend Baglantisi

Mobil uygulama gelistirme ortaminda su adresleri kullanir:

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator / macOS / Windows / Linux / web: `http://127.0.0.1:8000`

Bu nedenle mobil uygulamayi acmadan once backend'in ayakta oldugundan emin olun.

## Hizli Baslangic

Iki ayri terminal acip su sirayla ilerleyebilirsiniz:

Terminal 1:

```bash
cd backend
source .venv/bin/activate
uvicorn app:app --reload
```

Terminal 2:

```bash
cd mobile
flutter pub get
flutter run
```
