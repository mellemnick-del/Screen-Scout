# Screen Scout

Paste a YouTube or YouTube Kids link and get a parent-friendly content report: a verdict
(Safe / Use Caution / Not Recommended), a minimum age, a 9-category breakdown, timestamped
moments to know about, positives, and conversation starters.

```
ios/       SwiftUI iPhone/iPad app (open ScreenScout.xcodeproj in Xcode 16+)
backend/   Python service that fetches the video and asks Claude for the review
```

## Why there are two parts

The app can't call Claude directly: an API key shipped inside an App Store app can be pulled
out by anyone. So the iPhone app talks to your backend, and the backend holds the key.

The backend gathers three kinds of evidence:
1. Video details (title, channel, description, tags)
2. The captions, with timestamps
3. 16 still frames spread across the video, so it catches things with no dialogue

## Run it on your Mac

**1. Backend** (Terminal):

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
brew install ffmpeg deno
export ANTHROPIC_API_KEY=sk-ant-...
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Visit http://127.0.0.1:8000 for a quick browser test page.

**2. App:** double-click `ios/ScreenScout.xcodeproj`, choose an iPhone simulator, press Run.

If Xcode refuses to open the project file, run `brew install xcodegen && xcodegen` inside
`ios/` to regenerate it.

To run on your own iPhone: Signing & Capabilities, pick your Team, then set
`Config.swift` to your Mac's Wi-Fi IP (e.g. `http://192.168.1.20:8000`).

## Before submitting to the App Store

- [ ] Apple Developer Program membership ($99/yr)
- [ ] Change bundle ID `com.example.screenscout` to your own (Target, Signing & Capabilities)
- [ ] Host the backend over HTTPS (the included `Dockerfile` works on Render, Fly.io, Railway).
      Set `ANTHROPIC_API_KEY` and `SCOUT_APP_TOKEN` there, put the URL and token in `Config.swift`
- [ ] Add rate limiting or App Attest. The app token only slows down abuse; it doesn't stop it
- [ ] Privacy policy URL and App Privacy answers (the app sends video links to your server)
- [ ] List under Lifestyle or Parenting, **not** the Kids category (this app is for parents)
- [ ] Final name and icon, then screenshots

### Big risk to sort out first: YouTube's rules

The backend uses `yt-dlp` and caption scraping. That's fine for a personal prototype, but
YouTube's Terms of Service forbid downloading video outside their official tools. YouTube
also often blocks this kind of traffic from cloud servers, and Apple can reject apps built
on third-party content they aren't authorized to use (App Review Guideline 5.2). Before a public
launch, plan to move metadata to the official YouTube Data API and work out a compliant way to
see video content. Getting advice from someone who knows platform terms would be worth it.

## Cost

Each new review is one Claude Opus 5.5 call with about 16 small images plus the transcript,
so expect a few cents each. Reviews are cached per video and age, so repeat lookups are
free. If the app goes public, a subscription would cover this.
