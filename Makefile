SOURCES = bj.sh rollup.rb linebreak.rb
TARGETS = bj-1line.sh bj-80-col.sh bj-90-col.sh

.PHONY: all
all: $(TARGETS)

$(TARGETS): $(SOURCES)

bj-1line.sh:
	./rollup.rb bj.sh $@
	chmod +x $@

bj-80-col.sh: bj-1line.sh
	./linebreak.rb --max-lines 13 80 bj-1line.sh $@
	chmod +x $@

bj-90-col.sh: bj-1line.sh
	./linebreak.rb --max-lines 12 90 bj-1line.sh $@
	chmod +x $@
