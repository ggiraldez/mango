CRYSTAL := crystal
SOURCE := src/crystal-mango.cr
OUTPUT := mango

run:
	$(CRYSTAL) $(SOURCE)

mango:
	$(CRYSTAL) build -o $(OUTPUT) $(SOURCE)

release:
	$(CRYSTAL) build -o $(OUTPUT) --release $(SOURCE)

clean:
	rm -f mango


