{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, boost179
, gcc
, gfortran
, sqlite
, python3
, gdal
, bzip2
, expat
, flex
, bison
, udunits
, zlib
, wget
, mpich
, hdf5
, netcdf
, netcdffortran
, netcdfcxx
, pybind11
}:

let
  python = python3.withPackages (ps: with ps; [
    numpy
    pip
    wheel
    netcdf4
  ]);
in
stdenv.mkDerivation rec {
  pname = "ngen";
  version = "unstable-2024-07-18";

  src = fetchFromGitHub {
    owner = "NOAA-OWP";
    repo = "ngen";
    rev = "master";
    sha256 = ""; # Replace with the actual SHA256 hash of the repository
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    python
    gfortran
  ];

  buildInputs = [
    boost179
    sqlite
    gdal
    bzip2
    expat
    flex
    bison
    udunits
    zlib
    wget
    mpich
    hdf5
    netcdf
    netcdffortran
    netcdfcxx
    pybind11
  ];

  cmakeFlags = [
    "-DNGEN_WITH_EXTERN_ALL=ON"
    "-DNGEN_WITH_NETCDF=ON"
    "-DNGEN_WITH_BMI_C=ON"
    "-DNGEN_WITH_BMI_FORTRAN=ON"
    "-DNGEN_WITH_PYTHON=ON"
    "-DNGEN_WITH_ROUTING=ON"
    "-DNGEN_WITH_SQLITE=ON"
    "-DNGEN_WITH_UDUNITS=ON"
    "-DUDUNITS_QUIET=ON"
    "-DNGEN_WITH_TESTS=OFF"
    "-DCMAKE_BUILD_TYPE=Debug"
  ];

  preBuild = ''
    # Build and install T-Route
    git clone --depth 1 --single-branch --branch master https://github.com/NOAA-OWP/t-route.git
    cd t-route
    git submodule update --init --depth 1
    pip install -r requirements.txt
    ./compiler.sh no-e
    cd src/troute-network && python setup.py --use-cython bdist_wheel
    cd ../troute-routing && python setup.py --use-cython bdist_wheel
    cd ../troute-config && python -m build .
    cd ../troute-nwm && python -m build .
    pip install src/troute-*/dist/*.whl
    cd ../..

    # Update pybind11
    cd extern && rm -rf pybind11 && git clone https://github.com/pybind/pybind11.git && cd pybind11 && git checkout v2.12.0
    cd ../..
  '';

  postBuild = ''
    # Build parallel version
    cmake -G Ninja -B cmake_build_parallel -S . ''${cmakeFlags[@]} -DNGEN_WITH_MPI=ON
    cmake --build cmake_build_parallel --target all -- -j $NIX_BUILD_CORES
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib,share}
    cp -a cmake_build_serial/ngen $out/bin/ngen-serial
    cp -a cmake_build_parallel/ngen $out/bin/ngen-parallel
    cp -a cmake_build_parallel/partitionGenerator $out/bin/partitionGenerator
    ln -s $out/bin/ngen-parallel $out/bin/ngen

    cp -a extern/*/cmake_build/*.so* $out/lib/
    find ./extern/noah-owp-modular -type f -iname "*.TBL" -exec cp '{}' $out/share \;

    # Copy the Hello script
    cp ${./HelloNGEN.sh} $out/bin/HelloNGEN.sh
    chmod +x $out/bin/HelloNGEN.sh
  '';

  meta = with lib; {
    description = "Next Generation Water Resources Modeling Framework";
    homepage = "https://github.com/NOAA-OWP/ngen";
    license = licenses.unlicense;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
}
