MAIN = cotter-thesis.ltx

TALK = talk

BASE      := $(basename $(MAIN))
SRCEXT    := $(patsubst $(BASE).%,%,$(MAIN))
XFIGS     := $(wildcard fig/*.fig)
DIAFIGS   := $(wildcard fig/*.dia)
SVGFIGS   := $(wildcard fig/*.svg)
CORELFIGS := $(wildcard fig/*.cdr)
CORELPDF  := $(patsubst fig/%.cdr, fig/%.pdf, $(CORELFIGS))

TEXFIGS   := $(patsubst fig/%.fig, fig/%.tex, $(XFIGS)) # $(DIAFIGS:.dia=.tex)
BINFIGS   := $(patsubst fig/%.fig, fig/%.pdf, $(XFIGS)) \
    	     $(patsubst fig/%.dia, fig/%.pdf, $(DIAFIGS)) \
    	     $(patsubst fig/%.svg, fig/%.pdf, $(SVGFIGS))  


STYLINK	  := $(notdir $(wildcard ../*.sty))
STYFILES  := $(sort $(STYLINK) $(wildcard *.sty))
TEXFILES  := $(sort $(MAIN) $(wildcard *.tex) $(STYFILES) $(TEXFIGS))

BIBFILES  := $(wildcard *.bib)

RSLTS     := $(wildcard rslt/*.rslt.json)
JGRAPHS   := $(wildcard jgraph/*.j)
GGRAPHS   := $(wildcard gp/*.gp)
BARGRAPHS := $(wildcard gp/*.sh)
BAREPS    := $(patsubst gp/%.sh, graphs/%.eps, $(BARGRAPHS))
BARGRAPHDRIVER := $(patsubst %, gp/%, barchart barchart-stacked)
# Credit for the sed command goes to stackoverflow.com user Zsolt Botykai
#TEXTABLES := $(shell grep graph_file graph_gen.json | cut -d\" -f4 | sed ':a;N;$!ba;s/\n/ /g')

GRAPHS    := $(patsubst jgraph/%.j, graphs/%.pdf, $(JGRAPHS)) \
    	     $(patsubst gp/%.gp, graphs/%.pdf, $(filter-out gp/style.gp, $(GGRAPHS))) \
	     $(patsubst gp/%.sh, graphs/%.pdf, $(BARGRAPHS))

DATA      := $(wildcard dat/*.dat)

# LATEX \\def\\noeditingmarks{} \input
LATEX     = pdflatex #\\nonstopmode\\input
BIBTEX    = bibtex -min-crossrefs=1000
PS2PDF    = ps2pdf
RSLT2GRAPH = true
RSLT2GRAPHCONFIG = /dev/null
PYTHON    = python

SHA = shasum

all: $(BASE).pdf $(TALK).pdf

data-stamp: $(RSLTS) $(RSLT2GRAPH) $(RSLT2GRAPHCONFIG) $(wildcard *skeleton*)
# Depot way (also used in speak-up):
#	for i in `ls scripts/*.py scripts/*.pl scripts/*.sh`; do $$i; done
	mkdir -p dat; mkdir -p graphs
	$(PYTHON) $(RSLT2GRAPH) $(RSLT2GRAPHCONFIG)
	touch $@

# to include an xfig with embedded latex, you include the *tex* file:
# \begin{figure}
#    \input{foo}
# \end{figure}
#  where fig/foo.fig is an xfig file that you created with embedded latex.
%.pdf %.tex: %.fig
	fig2dev -L pdftex -p1 $< > $*.pdf
	fig2dev -L pdftex_t -p $*.pdf $< > $*.tex

%.pdf: %.eps
	perl -ne 'exit 1 unless /\n/' $< \
		|| perl -p -i -e 's/\r/\n/g' $<
	epstopdf --outfile=$@ $<

%.pdf: %.gif
	convert $< $@

%.tex: %.dia
	unset DISPLAY; dia -n -e $@ $<

# dirt-simple rule to build graphs. depends on gnuplot file printing its
# output (the PDF file) to stdout
graphs/%.pdf: gp/%.gp data-stamp 
	gnuplot < $< > $@

graphs/%.pdf: jgraph/%.j data-stamp 
	@rm -f $@~
	jgraph $< > $@~
	mv -f $@~ $@

graphs/%.pdf: gp/%.sh $(BARGRAPHDRIVER) data-stamp
	@rm -f $@~
	$< 

# convert SVG figures to PDF
fig/%.pdf: fig/%.svg
	@rm -f $@~
	inkscape --export-pdf=$@~ $<
	mv -f $@~ $@

$(STYLINK):
	rm -f $@
	ln -s ../$@ .

RERUN = egrep -q '(^LaTeX Warning:|\(natbib\)).* Rerun' $*.log
UNDEFINED = egrep -q '^(LaTeX|Package natbib) Warning:.* undefined' $*.log

# So you can "setenv ALWAYS yes" instead of butchering the Makefile...
ifneq ($(ALWAYS),)
ALWAYS = always
endif

$(BASE).pdf: %.pdf: %.$(SRCEXT) $(TEXFILES) $(BIBFILES) \
				$(BINFIGS) $(GENTEX) $(TEXFIGS)	\
				$(ALWAYS) $(TEXTABLES) $(CORELPDF) $(GRAPHS)
	test ! -s $*.aux || $(BIBTEX) $* || rm -f $*.aux $*.bbl
	$(LATEX) $< || ! rm -f $@
	if $(UNDEFINED); then \
		$(BIBTEX) $* && $(LATEX) $< || ! rm -f $*.bbl $@; \
	fi
	! $(RERUN) || $(LATEX) $< || ! rm -f $@
	! $(RERUN) || $(LATEX) $< || ! rm -f $@
	touch $*.dvi
	test ! -f .xpdf-running || xpdf -remote $(BASE)-server -reload

$(TALK).pdf: %.pdf: %.$(SRCEXT) $(TEXFILES) $(BIBFILES) \
				$(BINFIGS) $(GENTEX) $(TEXFIGS)	\
				$(ALWAYS) $(TEXTABLES) $(CORELPDF) $(GRAPHS)
	test ! -s $*.aux || $(BIBTEX) $* || rm -f $*.aux $*.bbl
	$(LATEX) $< || ! rm -f $@

%.pdf: %.ltx
	$(LATEX) $< || !rm -f $@
	! $(RERUN) || $(LATEX) $< || ! rm -f $@
	! $(RERUN) || $(LATEX) $< || ! rm -f $@

$(TEXTABLES): $(RSLT2GRAPH) $(RSLT2GRAPHCONFIG) $(RSLTS) data-stamp

DIST = GNUmakefile $(filter-out $(GENTEX) $(TEXFIGS), $(TEXFILES)) \
	$(XFIGS) $(DIAFIGS) \
	$(JGRAPHS) $(GGRAPHS) $(BARGRAPHS) \
	$(BARGRAPHDRIVER) \
	$(RSLTS) \
	$(BIBFILES)
dist: $(BASE).tar.gz
$(BASE).tar.gz: $(DIST)
	tar -chzf $@ -C .. \
		$(patsubst %, $(notdir $(PWD))/%, $(DIST))

PREVIEW := $(BASE)
preview: $(PREVIEW).pdf
	if test -f .xpdf-running; then			\
		xpdf -remote $(BASE)-server -quit;	\
		sleep 1;				\
	fi
	touch .xpdf-running
	(xpdf -remote $(BASE)-server $(PREVIEW).pdf; rm -f .xpdf-running) &

show: $(BASE).pdf
	xpdf -fullscreen $(BASE).pdf

osx: $(BASE).pdf
	open $(BASE).pdf

anon: $(BASE)-anon.pdf

double:
	for i in $(TEXFILES); do perl double.pl $$i; done

# stupid hack to anonymize a PDF. it's maybe ridiculous that this
# works.
$(BASE)-anon.pdf: $(BASE).pdf
	$(PS2PDF) $< $@

EXTRAIGNORE = '*~' '*.aux' '*.bbl' '*.blg' '*.log' '*.dvi' '*.bak' '*.out' 
ignore:
	rm -f .gitignore
	(for file in $(EXTRAIGNORE); do \
		echo "$$file"; \
	done; \
	for file in .xpdf-running \
			$(BASE).tar.gz \
			$(GENTEX) $(TEXFIGS) $(BINFIGS) $(GRAPHS) \
			$(BASE).ps $(BASE).pdf; do \
		echo "/$$file"; \
	done) | sort > .gitignore
	git add .gitignore

clean: 
	rm -f $(BASE).ps $(BASE).pdf $(BASE).tar.gz
	rm -f $(TEXFIGS) $(BINFIGS) $(GRAPHS)
	rm -f $(GENTEX)
	rm -f $(DATA)
	rm -f *.dvi *.aux *.log *.bbl *.blg *.lof *.lot *.toc *.bak *.out
	rm -f *~ *.core core
	rm -f plot.plt
	rm -f $(BAREPS)
	rm -f data-stamp

always:
	@:

.PHONY: install clean all always ignore preview show osx dist 

spell:
	make clean
	for i in $(wildcard *.tex); do aspell -p ./aspell.words -c $$i; done
