# Multipart Example

```powershell
curl -X POST http://localhost:8130/v1/alter-lens/analyze `
  -F "scan_type=startup_deck" `
  -F "user_context=Demo night investor room" `
  -F "image=@deck-slide.jpg;type=image/jpeg"
```
