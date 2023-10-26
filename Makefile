JULIA = julia --startup-file=no --color=yes --project=.

install:
	$(JULIA) -e 'import Pkg; Pkg.instantiate()'

test:
	$(JULIA) -e 'using Pkg; Pkg.test()'

all:
	install
	test
