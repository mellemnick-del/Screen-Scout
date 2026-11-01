"""Turn video evidence into a parent-facing content report using Claude."""

from __future__ import annotations

from typing import List, Literal

import anthropic
from pydantic import BaseModel, Field

from .youtube import VideoEvidence, fmt_ts

MODEL = "claude-opus-5-5"

Level = Literal["none", "mild", "moderate", "strong", "severe"]
CategoryName = Literal[
    "violence",
    "scary_or_disturbing",
    "language",
    "sexual_content",
    "dangerous_imitable_behavior",
    "bad_behavior_and_attitudes",
    "commercialism",
    "misleading_or_hijacked_characters",
    "overstimulation",
]


class CategoryRating(BaseModel):
    category: CategoryName
    level: Level
    details: str = Field(description="One or two plain sentences on what the parent should know. Say 'Nothing found.' if none.")


class FlaggedMoment(BaseModel):
    timestamp: str = Field(description="m:ss or h:mm:ss where it happens, or 'throughout'")
    category: CategoryName
    description: str


class Report(BaseModel):
    verdict: Literal["safe", "caution", "not_recommended"]
    recommended_min_age: int = Field(description="Youngest age this is appropriate for, 2 to 18")
    fit_for_child: Literal["good_fit", "watch_together", "skip"] = Field(
        description="Fit for the specific child age the parent gave"
    )
    headline: str = Field(description="One short sentence verdict a busy parent can read in two seconds")
    summary: str = Field(description="What the video actually is and what happens in it, 3-5 sentences")
    categories: List[CategoryRating] = Field(description="Exactly one entry for every category")
    flagged_moments: List[FlaggedMoment]
    positives: List[str] = Field(description="Educational value, good messages, creativity. Empty if none.")
    educational_value: Level
    talk_about_it: List[str] = Field(description="2-4 questions or conversation starters for parent and child")
    confidence: Literal["high", "medium", "low"]
    confidence_reason: str = Field(description="What evidence the rating was based on and any gaps")


SYSTEM = """You review online videos for parents of young children, the way an experienced, \
level-headed media reviewer would. Parents use your report to decide whether their kid \
should watch something, so be accurate, specific, and calm. Don't moralize and don't \
inflate harmless things; a cartoon pratfall is not "violence: strong". Equally, don't \
miss the things parents genuinely worry about on kids' platforms:

- Familiar characters (cartoon, superhero, toy) placed in violent, gross, sexual, medical, \
  or frightening situations, often in content made to game the algorithm.
- Pranks, challenges, and stunts a child might copy (choking, fire, climbing, ingesting things).
- Disguised advertising: unboxing hauls, "toy reviews" that are paid, pushes to buy, \
  subscribe, or beg parents.
- Mean, bratty, or disrespectful behavior presented as funny or rewarded.
- Jump scares, creepy imagery, or distress (crying babies, injections, kidnapping themes).
- Hyper-stimulating editing: constant loud noises, flashing, rapid cuts with no substance.

You'll get the video's metadata, a timestamped transcript if one exists, and still frames \
sampled across the video with their timestamps. Base the rating only on this evidence. \
Where the evidence is thin (no transcript, few frames), say so and lower your confidence \
rather than guessing. Cite timestamps for anything flagged.

Verdict guide: "safe" means a typical parent would be fine with it for the recommended age; \
"caution" means there's something worth knowing or watching together; "not_recommended" \
means most parents of the target age would not want their child watching it.

Write in plain, everyday language. No jargon. Never use em dashes."""


def _build_content(ev: VideoEvidence, child_age: int | None) -> list[dict]:
    meta = [
        f"Title: {ev.title}",
        f"Channel: {ev.channel}",
        f"Length: {fmt_ts(ev.duration)}",
        f"Marked 'made for kids' by uploader: {ev.made_for_kids}",
        f"Views: {ev.view_count}",
        f"Tags: {', '.join(ev.tags) if ev.tags else '(none)'}",
        f"Description:\n{ev.description or '(none)'}",
    ]
    if ev.transcript:
        lines = "\n".join(f"[{fmt_ts(t)}] {txt}" for t, txt in ev.transcript)
        transcript = f"<transcript>\n{lines}\n</transcript>"
    else:
        transcript = "<transcript>No captions available.</transcript>"

    content: list[dict] = [{"type": "text", "text": "<metadata>\n" + "\n".join(meta) + "\n</metadata>"}]
    if ev.frames:
        content.append({"type": "text", "text": f"Here are {len(ev.frames)} frames sampled evenly across the video:"})
        for f in ev.frames:
            content.append({"type": "text", "text": f"Frame at {fmt_ts(f.timestamp)}:"})
            content.append({"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": f.jpeg_b64}})
    elif ev.thumbnail_url:
        content.append({"type": "text", "text": "No frames could be sampled. Here is the thumbnail:"})
        content.append({"type": "image", "source": {"type": "url", "url": ev.thumbnail_url}})

    content.append({"type": "text", "text": transcript})
    if ev.notes:
        content.append({"type": "text", "text": "Evidence gaps: " + " ".join(ev.notes)})
    age_line = f"The parent's child is {child_age} years old." if child_age else "The parent didn't give a child age; judge fit for a 6 year old."
    content.append({"type": "text", "text": f"{age_line}\n\nWrite the content report."})
    return content


class AnalysisError(Exception):
    pass


def analyze(ev: VideoEvidence, child_age: int | None, client: anthropic.Anthropic | None = None) -> Report:
    client = client or anthropic.Anthropic()
    try:
        response = client.beta.messages.parse(
            model=MODEL,
            max_tokens=16000,
            system=SYSTEM,
            messages=[{"role": "user", "content": _build_content(ev, child_age)}],
            output_format=Report,
            output_config={"effort": "medium"},
            # If a safety classifier declines (e.g. a disturbing video), let the
            # API retry on Anthropic's recommended fallback model automatically.
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        )
    except anthropic.AuthenticationError as e:
        raise AnalysisError("Claude API key is missing or invalid. Set ANTHROPIC_API_KEY.") from e
    except anthropic.RateLimitError as e:
        raise AnalysisError("Claude is rate limited right now. Try again in a minute.") from e
    except anthropic.APIStatusError as e:
        raise AnalysisError(f"Claude API error ({e.status_code}): {e.message}") from e
    except anthropic.APIConnectionError as e:
        raise AnalysisError("Couldn't reach the Claude API.") from e

    if response.stop_reason == "refusal":
        raise AnalysisError(
            "The reviewer declined to analyze this video. That usually means the content itself "
            "is seriously inappropriate. Treat it as not safe for kids."
        )
    if response.stop_reason == "max_tokens" or response.parsed_output is None:
        raise AnalysisError("The review came back incomplete. Try again.")
    return response.parsed_output
