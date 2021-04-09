#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import os
import ruamel.yaml

from ruamel.yaml.scalarstring import DoubleQuotedScalarString

# For a command like this...
#
# explode_yaml_file.py zcash/contrib/gitian-descriptors/gitian-linux.yml suites output_dir
#
# ...with a gitian-linux.yml file like this...
#
# ---
# distro: "debian"
# suites:
# - "jessie"
# - "stretch"
# architectures:
# - "amd64"
#
# ...will write out a structure like this:
#
# output_dir/
# ├─ jessie/
# │  └─ gitian-linux.yml  content:
# │                       ---
# │                       distro: "debian"
# │                       suites:
# │                       - "jessie"
# │                       architectures:
# │                       - "amd64"
# │
# └─ stretch
#    └─ gitian-linux.yml  content:
#                         ---
#                         distro: "debian"
#                         suites:
#                         - "stretch"
#                         architectures:
#                         - "amd64"
#
# This approach is working around a limitation of gitian-builder: when
# passed a descriptor file with more than one entry in 'suites', it
# overwrites products of earlier builds with products of later builds.
# We 'explode' our descriptor file into potentially many single-suite
# descriptor files which we then pass to gitian-builder one at a time.


parser = argparse.ArgumentParser(description='YAML file exploder')

parser.add_argument('input_file_path',
                    type=str,
                    help='Path to the input file')

parser.add_argument('key_to_explode',
                    type=str,
                    help='The key in the input file to explode (should be a sequence)')

parser.add_argument('output_dir_path',
                    type=str,
                    help='Path to the output directory')

args = parser.parse_args()

yaml = ruamel.yaml.YAML()
yaml.preserve_quotes = True

input_file_path = args.input_file_path
output_dir_path = args.output_dir_path

file_name = os.path.basename(input_file_path)


with open(input_file_path) as fp:
    data = yaml.load(fp)

sequence = data[args.key_to_explode]

for item in sequence:
    print(item)
    item_dir_path = os.path.join(output_dir_path, item)

    if not os.path.exists(item_dir_path):
        os.makedirs(item_dir_path)

    data[args.key_to_explode] = [DoubleQuotedScalarString(item)]

    output_file_path = os.path.join(item_dir_path, file_name)
    with open(output_file_path, 'w') as fp:
        yaml.dump(data, fp)
