.PHONY: build run test app clean bump-version

build:
	swift build

run: build
	swift run $(APP_EXECUTABLE)

test:
	@if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then \
		DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test; \
	else \
		swift test; \
	fi

app:
	./packaging/build-app.sh

clean:
	rm -rf .build dist

bump-version:
	chmod +x packaging/bump-version.sh
	./packaging/bump-version.sh $(or $(BUMP),patch)
