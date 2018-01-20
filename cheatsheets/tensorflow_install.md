
 ValueError: ZIP does not support timestamps before 1980 #129
https://github.com/garbas/pypi2nix/issues/129
https://nixos.org/nixpkgs/manual/#python-setup.py-bdist_wheel-cannot-create-.whl

SOURCE_DATE_EPOCH=$(date +%s) ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
