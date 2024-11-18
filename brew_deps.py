#!/usr/bin/env python3
"""
Prints brew packages, installed manually, with dependencies count
"""

import subprocess
from typing import Dict, List


def deps_tree() -> Dict[str, int]:
    curpkg = ''
    count = 0
    pkgs = {}
    for pkg in subprocess.check_output('brew deps --tree --installed', shell=True).decode('utf-8').split('\n'):
        pkg = pkg.strip()
        if len(pkg) > 0 and pkg[0].isalnum():
            curpkg = pkg
        elif len(pkg) > 0:
            count += 1
        else:
            pkgs[curpkg] = count
            curpkg = ''
            count = 0
    return pkgs


def deps_tree_leaves() -> List[str]:
    leaves = subprocess.check_output('brew leaves', shell=True).decode('utf-8').split('\n')
    return [leave.strip() for leave in leaves]


def main():
    pkgs = deps_tree()  # package name => dependencies count
    leaves = deps_tree_leaves()  # Only installed manually

    for pkg, deps in sorted(pkgs.items(), key=lambda item: int(item[1]), reverse=False):
        if pkg not in leaves:
            continue
        print(f'Pkg: {pkg:<20} deps: {deps}')
