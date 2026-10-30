"""Synthesize a placeholder spoken line with Windows SAPI, encoded to Ogg Vorbis.

Placeholder only: real recordings replace these files later with no code changes.
Usage: python3 tools/make_voice.py "Who do you want to play as?" assets/audio/who-do-you-want.ogg [Female|Male]
       python3 tools/make_voice.py --list
"""
import subprocess
import sys
from pathlib import Path

POWERSHELL = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"


def list_voices() -> list[str]:
    script = ("Add-Type -AssemblyName System.Speech;"
              "(New-Object System.Speech.Synthesis.SpeechSynthesizer).GetInstalledVoices() | "
              "ForEach-Object { $_.VoiceInfo.Name + '|' + $_.VoiceInfo.Gender }")
    out = subprocess.run([POWERSHELL, "-NoProfile", "-Command", script], check=True, capture_output=True, text=True).stdout
    return [l.strip() for l in out.splitlines() if l.strip()]


def synth_wav(text: str, wav: Path, gender: str = "Female", rate: int = -1) -> str:
    """Speak text into wav with an installed voice of the given gender; returns the voice name used."""
    win_wav = subprocess.run(["wslpath", "-w", str(wav)], check=True, capture_output=True, text=True).stdout.strip()
    text = text.replace("'", "''").replace('"', '`"')
    script = (
        "Add-Type -AssemblyName System.Speech;"
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        f"$f = $s.GetInstalledVoices() | Where-Object {{ $_.VoiceInfo.Gender -eq '{gender}' }} | Select-Object -First 1;"
        "if ($f) { $s.SelectVoice($f.VoiceInfo.Name) };"
        f"$s.Rate = {rate};"
        f"$s.SetOutputToWaveFile('{win_wav}');"
        f"$s.Speak(\"{text}\");"
        "$s.Dispose();"
        "Write-Output $s.Voice.Name"
    )
    r = subprocess.run([POWERSHELL, "-NoProfile", "-Command", script], check=True, capture_output=True, text=True)
    return r.stdout.strip()


def speak(text: str, dst: Path, gender: str = "Female", rate: int = -1, quality: int = 5) -> str:
    import import_art  # docker helpers; imported here to avoid a cycle at module load

    dst = Path(dst).resolve()
    wav = dst.with_suffix(".wav")
    voice = synth_wav(text, wav, gender, rate)
    cli, mount = import_art.docker()
    try:
        subprocess.run(cli + [
            "run", "--rm", "-v", f"{mount(dst.parent)}:/a", import_art.FFMPEG_IMAGE, "-y", "-loglevel", "error",
            "-i", f"/a/{wav.name}", "-ac", "1", "-c:a", "libvorbis", "-q:a", str(quality), f"/a/{dst.name}",
        ], check=True)
    finally:
        wav.unlink(missing_ok=True)
    return voice


if __name__ == "__main__":
    if sys.argv[1] == "--list":
        print("\n".join(list_voices()))
    else:
        speak(sys.argv[1], Path(sys.argv[2]), sys.argv[3] if len(sys.argv) > 3 else "Female")
