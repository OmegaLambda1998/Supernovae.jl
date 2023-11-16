JULIA = julia --startup-file=no --color=yes --project=.

install:
	$(JULIA) -e 'import Pkg; Pkg.instantiate()'
	env PYTHON="./venv/bin/python3" $(JULIA) -e 'import Pkg; Pkg.build("PyCall")'

test:
	$(JULIA) -e 'using Pkg; Pkg.test()'

all:
	install
	test
