#!/bin/sh
set -eu
exec opencode run --agent revisor "Revisa src/sparktune, acciones.json y las pruebas Python según las reglas de este proyecto."
