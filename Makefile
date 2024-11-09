ZIP_FILE = function.zip
SOURCE_FILE = index.js

all: $(ZIP_FILE)

# .zipファイルの作成
$(ZIP_FILE): $(SOURCE_FILE)
	zip -r $(ZIP_FILE) $(SOURCE_FILE) node_modules

# .zipファイルの削除
remove:
	rm -f $(ZIP_FILE)