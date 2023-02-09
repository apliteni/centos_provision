# python 3 headers, required if submitting to Ansible
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = """
  lookup: upgrade_chekpoints
  short_description: build a list of chekpoints to be played on upgrade
  description:
      - This lookup returns the list of upgrade checkpoint names to be played on upgrade.
  options:
    _root:
      description: the root directory containing checkpoint directories with upgrading tasks
      required: True
    _current_version:
      description: current installed version
      required: True
  notes:
    Example
      Version 2.27.1 is installed on the target box.

      tasks/
      |
      +-- 2.27.0/
      |   |
      |   +-- main.yml
      |
      +-- 2.27.1/
      |   |
      |   +-- main.yml
      |
      +-- 2.29.0/
          |
          +-- main.yml

     This lookup will return ['2.27.1', '2.29.0']

"""
from ansible.plugins.lookup import LookupBase
from ansible.utils.display import Display
from ansible.module_utils._text import to_text
from distutils.version import StrictVersion

import os
import re

display = Display()

# Based on https://github.com/ansible-collections/community.general/blob/main/plugins/lookup/filetree.py

class LookupModule(LookupBase):

    def run(self, terms, variables=None, **kwargs):
        kctl_tags = variables['kctl_tags']

        if ('upgrade' in kctl_tags) or ('full-upgrade' in kctl_tags):
            since = '0.9' if ('full-upgrade' in kctl_tags) else variables['kctl_installed_version']
            upgrade_checkpoint_to_path_map = self.__upgrade_checkpoint_to_path_map(terms[0], variables, since)
            return self.__upgrade_checkpoint_paths(upgrade_checkpoint_to_path_map, since)
        else:
            return []


    def __upgrade_checkpoint_to_path_map(self, term, variables, since):
        result = {}
        basedir = self.get_basedir(variables)
        display.display("Lookup upgrade checkpoints to be played on upgrade from %s in the %s directory" % \
                        (since, term))
        term_file = os.path.basename(term)
        dwimmed_path = self._loader.path_dwim_relative(basedir, 'files', os.path.dirname(term))
        path = os.path.join(dwimmed_path, term_file)
        for root, dirs, files in os.walk(path, topdown=True):
            for entry in files:
                full_path = os.path.join(root, entry)
                rel_path = os.path.relpath(full_path, path)
                match = re.match(r"^(\d+(\.\d+)+)/main.yml$", rel_path)
                if match:
                    result[match.group(1)] = full_path

        return result


    def __upgrade_checkpoint_paths(self, upgrade_checkpoint_to_path_map, since):
        result = []
        upgrade_checkpoint_versions = list(upgrade_checkpoint_to_path_map.keys())
        upgrade_checkpoint_versions.sort(key=StrictVersion)
        display.vvv("Found upgrdade checkpoints: %s" % upgrade_checkpoint_versions)

        for upgrade_checkpoint in upgrade_checkpoint_versions:
            if self.__playable_on_upgrade(upgrade_checkpoint, since):
                result.append(upgrade_checkpoint_to_path_map[upgrade_checkpoint])

        display.display("Following upgrdade checkpoint will be played: %s" % result)

        return result


    def __playable_on_upgrade(self, upgrade_checkpoint, since):
        since_patch = re.match(r"^((\d+)(\.\d+){1,2})", since).group(1)

        return (StrictVersion(to_text(upgrade_checkpoint)) >= StrictVersion(to_text(since_patch)))
