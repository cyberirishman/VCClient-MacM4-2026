# Convenience wrappers. Run `make setup` first, then `make webui` to train,
# then `make realtime` for the live voice changer.
.PHONY: setup webui realtime lock clean uninstall purge

setup:
	./setup.sh

webui:
	./run-webui.sh

realtime:
	./run-realtime.sh

lock:
	. .venv/bin/activate && uv pip freeze > locked-requirements.txt && echo "Wrote locked-requirements.txt"

clean:
	rm -rf .venv
	@echo "Removed .venv. Upstream checkout + models under RVC-WebUI-MacOS/ left intact."

uninstall:
	./cleanup.sh

purge:
	./cleanup.sh --all
