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

**First time:** in Xcode choose **Integrate → Clone…**, paste
`https://github.com/mellemnick-del/Screen-Scout.git`, and save it in Documents.
Then in Signing & Capabilities pick your Team.

**Start the server** (Terminal):

```bash
cd ~/Documents/Screen-Scout/backend && ./start.sh
```

The first run sets up Python on its own. You need `brew install ffmpeg deno` once, and
`ANTHROPIC_API_KEY` saved in `~/.zshrc`. Saved reviews and accounts live in `~/ScreenScout-data`.

**Run the app:** press ▶ Run in Xcode. The app talks to the online server at
https://screen-scout-pz4e.onrender.com (set in `ios/ScreenScout/Config.swift`). Running the
server on your Mac is only needed for testing server changes locally.

**Get updates:** in Xcode choose **Integrate → Pull…**, then Run. If the server changed,
stop it with Ctrl + C and run `./start.sh` again.

## Accounts and families

Parents sign in with Apple. Everyone starts in their own family; others join with a
6-character invite code from the Account screen. A family shares one list of scouted
videos across all its members and devices.

- Each family gets `SCOUT_MONTHLY_LIMIT` new reviews per month (default 50, `0` = unlimited).
  Opening a video anyone has already scouted is free.
- Up to `SCOUT_MAX_FAMILY_SIZE` people per family (default 6).
- In Xcode, the target needs the **Sign in with Apple** capability
  (Signing & Capabilities, then + Capability).
- `SCOUT_APPLE_BUNDLE_ID` on the server must match the app's bundle identifier
  (default `com.example.screenscout`).
- Account deletion is built in. To also revoke Apple sign-in on deletion (Apple requires
  this for App Store apps), create a Sign in with Apple key at developer.apple.com
  (Certificates, IDs & Profiles, then Keys) and set `APPLE_TEAM_ID`, `APPLE_KEY_ID`, and
  `APPLE_PRIVATE_KEY_PATH` (path to the downloaded `.p8` file) on the server.

## Before submitting to the App Store

- [ ] Apple Developer Program membership ($99/yr)
- [ ] Change bundle ID `com.example.screenscout` to your own (Target, Signing & Capabilities)
- [ ] Host the backend over HTTPS (the included `Dockerfile` works on Render, Fly.io, Railway).
      Set `ANTHROPIC_API_KEY` and `SCOUT_APPLE_BUNDLE_ID` there and put the URL in `Config.swift`
- [ ] Turn on Apple sign-in revocation (see Accounts below). App Review checks account deletion
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
