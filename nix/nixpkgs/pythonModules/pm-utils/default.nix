#{stdenv, click, pm-utils, suds-jurko, pandas, inireader,  buildPythonPackage}:
{stdenv, pathlib, six, werkzeug, apscheduler, openpyxl, mock, numpy,
pandas, requests, xmltodict, buildPythonPackage}:

buildPythonPackage rec {
  name = "pm-utils";

  src = /home/gjeusel/lib-engie/prove_team-pm-utils-c809de16603b ;

  buildInputs = [pathlib six werkzeug apscheduler mock numpy
pandas requests xmltodict];
  propagatedBuildInputs = [pathlib six werkzeug apscheduler mock numpy
pandas requests xmltodict];

}



