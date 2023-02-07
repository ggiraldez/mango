CRYSTAL := crystal

run:
	$(CRYSTAL) src/crystal-mango.cr

mango:
	$(CRYSTAL) build -o mango src/crystal-mango.cr

clean:
	rm -f mango


