# Spoke for Mac

Voice dictation for macOS that types clean text into any app. Press your trigger (a spare mouse button or a key), talk, and press it again. Your words appear wherever your cursor is, already tidied: filler words gone, punctuation fixed, and mid-sentence corrections applied.

It's an open-source take on the click-and-talk experience of apps like Wispr Flow, using API keys you bring yourself. There's also [Spoke for Android](https://github.com/gstout52/spoke).

## What it does

- **Any trigger you like.** A spare mouse button (middle, back, forward, or any extra button), Right Option, Right Command, or Fn. Choose "press to start, press to finish" or "hold while talking." Esc cancels.
- **Works everywhere.** Text is typed into whatever app has focus, and your clipboard is put back afterward.
- **Accurate transcription.** Whisper via [Groq](https://console.groq.com) (free tier available) or OpenAI.
- **Cleanup that keeps your voice.** Claude Haiku removes "um / uh / like / you know", keeps only the final version when you correct yourself ("Tuesday, no, Wednesday"), fixes punctuation, and puts dictated lists on separate lines. It doesn't rewrite your wording, and it never answers your dictation as if it were a question.
- **Your vocabulary.** List names and jargon once and both steps spell them correctly.
- **Stays out of the way.** It lives in the menu bar, with a small pill at the bottom of the screen showing a level meter while you talk.

## Install

1. Download `Spoke-mac.zip` from the [latest release](../../releases/latest), unzip it, and drag **Spoke** into **Applications**.
2. The first time, **right-click Spoke → Open**, then confirm. (Spoke isn't notarized by Apple, so macOS asks once.) If macOS still refuses, go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. In Spoke's Settings window:
   - Grant **Microphone** and **Accessibility** access. Accessibility lets Spoke notice your trigger and type the result.
   - Paste a [Groq](https://console.groq.com) (free tier) or [OpenAI](https://platform.openai.com) key for speech-to-text.
   - Optionally paste an [Anthropic](https://console.anthropic.com) key for cleanup. Without one, you get the raw transcript.
   - Pick your trigger. For a mouse button, click **Change…** and press the button.
4. Click into any text field, press your trigger, talk, and press it again.

Requires macOS 13 or newer, on Apple silicon or Intel.

**Updating:** downloaded releases are signed ad-hoc, so macOS treats each new version as a different app. After updating, remove Spoke from **Privacy & Security → Accessibility** and add it again. To avoid this, build it yourself with a stable signing identity (below).

## Privacy

- Audio goes directly from your Mac to the speech-to-text provider you choose. Transcripts go to Anthropic only if cleanup is on. There's no Spoke server, analytics or tracking.
- API keys are stored in your macOS Keychain.
- Accessibility access is used to listen for your trigger, check the character before your cursor (so dictation doesn't run into the previous word), and paste the result. Spoke doesn't log keystrokes or read other screen content.
- Your clipboard is restored after each dictation, and the temporary entry is marked so clipboard managers skip it.

## Costs

You pay the providers directly with your own keys. Groq's free tier covers typical personal use. Cleanup with Claude Haiku costs a fraction of a cent per dictation.

## Building it yourself

You need Xcode (or the Xcode command-line tools) on macOS 13+.

```bash
./scripts/build.sh            # builds build/Spoke.app, signed ad-hoc
```

To keep macOS permissions across rebuilds, sign with a stable identity. Any code-signing certificate works, including a self-signed one kept in its own keychain:

```bash
SPOKE_SIGN_ID="<identity SHA-1>" SPOKE_KEYCHAIN=/path/to/signing.keychain-db ./scripts/build.sh
```

`scripts/install-local.sh` does this with an identity named "Spoke Local Signing" in `~/.spoke-mac/signing.keychain-db` and installs the result to `/Applications`.

| File | Role |
|---|---|
| `AppController.swift` | The dictation flow: trigger, record, transcribe, clean up, paste |
| `TriggerMonitor.swift` | System-wide mouse button / key listener (Quartz event tap) |
| `Recorder.swift` | Microphone recording |
| `Transcriber.swift` | Whisper speech-to-text (Groq or OpenAI) |
| `Cleaner.swift` | Claude cleanup prompt and call |
| `Inserter.swift` | Pastes into the focused app and restores the clipboard |
| `HUD.swift` | The floating status pill |
| `SettingsView.swift` | Settings window |

## Contributing

Issues and pull requests are welcome. Because this app runs with Accessibility access, every change is reviewed by hand before merging. Changes that send data anywhere new, or read more than they need to, need a clear reason.

Please don't report security problems in public issues. Use GitHub's **Report a vulnerability** button under the Security tab instead.

## License

[MIT](LICENSE)
