source $stdenv/setup

# The archives hierarchy isn't well named, we need to handle this manually :
mkdir -p $out/include
tar zxf $src --directory=$out/include --transform 's,cute_lib/,,' --wildcards --no-anchore "cute_lib/*"

# Extract examples
mkdir $out/examples
tar zxvf $src --directory=$out/examples --transform 's,cute_examples/,,' --wildcards --no-anchore "cute_examples/*"

# Extract tests
mkdir $out/tests
tar zxvf $src --directory=$out/tests --transform 's,cute_tests/,,' --wildcards --no-anchore "cute_tests/*"
