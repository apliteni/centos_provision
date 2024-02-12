# python 3 headers, required if submitting to Ansible
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = """
  lookup: update_chekpoints
  short_description: build a list of chekpoints to be played on update
  description:
      - This lookup returns the list of update checkpoint names to be played on update.
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
       ansible_facts = variables['ansible_facts']
       env = ansible_facts['env']

       running_mode = env['RUNNING_MODE']

       if running_mode != 'install' and running_mode != "tune":
           since = env['APPLIED_KCTL_VERSION']
           update_checkpoint_to_path_map = self.__update_checkpoint_to_path_map(terms[0], variables, since)
           return self.__update_checkpoint_paths(update_checkpoint_to_path_map, since)
       else:
           return []


    def __update_checkpoint_to_path_map(self, term, variables, since):
        result = {}
        basedir = self.get_basedir(variables)
        display.display("Lookup update checkpoints to be played on update from %s in the %s directory" % \
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


    def __update_checkpoint_paths(self, update_checkpoint_to_path_map, since):
        result = []
        update_checkpoint_versions = list(update_checkpoint_to_path_map.keys())
        update_checkpoint_versions.sort(key=StrictVersion)
        display.vvv("Found upgrdade checkpoints: %s" % update_checkpoint_versions)

        for update_checkpoint in update_checkpoint_versions:
            if self.__playable_on_update(update_checkpoint, since):
                result.append(update_checkpoint_to_path_map[update_checkpoint])

        display.display("Following upgrdade checkpoint will be played: %s" % result)

        return result


    def __playable_on_update(self, update_checkpoint, since):
        since_patch = re.match(r"^((\d+)(\.\d+){1,2})", str(since)).group(1)

        return (StrictVersion(to_text(update_checkpoint)) >= StrictVersion(to_text(since_patch)))
