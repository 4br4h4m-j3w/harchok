#!/bin/bash
cd ./extensions
find . -name "*.vsix" -exec code --install-extension {} \;
