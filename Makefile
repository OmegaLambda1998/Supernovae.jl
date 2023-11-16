JULIA = julia --startup-file=no --color=yes --project=.

conda: venv
	conda create --prefix ./venv
	conda install -c conda-forge astroquery

install:
	$(JULIA) -e 'import Pkg; Pkg.instantiate()'
	env PYTHON="./venv/bin/python3" $(JULIA) -e 'import Pkg; Pkg.build("PyCall")'

test:
	$(JULIA) -e 'using Pkg; Pkg.test()'

all:
	conda
	install
	test
