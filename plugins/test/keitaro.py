#!/usr/bin/python

class TestModule(object):
    def tests(self):
        return {
            'with_upgrade_tag': self.with_upgrade_tag,
        }
 
    def with_upgrade_tag(self, kctl_tags):
        return ('upgrade' in kctl_tags) or ('full-upgrade' in kctl_tags)
