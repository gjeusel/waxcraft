#{stdenv, click, pm-utils, suds-jurko, pandas, inireader,  buildPythonPackage}:
{stdenv, pathlib, six, werkzeug, apscheduler, openpyxl, mock, numpy,
pandas, requests, xmltodict, buildPythonPackage}:

buildPythonPackage rec {
  name = "pm-utils";

  src = /media/sf_windows/pythonModule_engie/pm-utils.tar.gz ;

  buildInputs = [pathlib six werkzeug apscheduler mock numpy
pandas requests xmltodict];
  propagatedBuildInputs = [pathlib six werkzeug apscheduler mock numpy
pandas requests xmltodict];

}



