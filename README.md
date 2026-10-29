# Jack-Jack and Becca's Cruise Adventure

A one-screen Godot 4.7.2 game for Jack (6) and Becca (4): drag the shirt into the suitcase. See `docs/` for the spec and design.

## Local commands

All Godot commands run inside the pinned CI image (`barichello/godot-ci:4.7.2`) through `tools/godot.sh`, so you never need Godot installed. Docker Desktop must be running.

```bash
tools/godot.sh --headless --import                               # import assets (first run, or after art changes)
tools/godot.sh --headless --script res://tests/run_tests.gd     # run the tests
mkdir -p build/web && tools/godot.sh --headless --export-release "Web" build/web/index.html
python3 -m http.server 8060 -d build/web                         # play at http://localhost:8060
```
