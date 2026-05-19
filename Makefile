EMACS ?= emacs -batch -q -Q --no-site-file

all: ox-jekyll.elc
ox-jekyll.elc: ox-jekyll.el
	$(EMACS) $(LOAD) -l tests/test-helper.el \
	-batch -f batch-byte-compile $<

test: ox-jekyll.elc
	$(EMACS) $(EMACSFLAGS) -l ert \
		-l tests/test-helper.el \
		-l ox-jekyll.el \
		-l tests/ox-jekyll-tests.el \
		-f ert-run-tests-batch-and-exit

clean:
	rm -f ox-jekyll.elc

distclean: clean
	rm -fr .test-elpa
