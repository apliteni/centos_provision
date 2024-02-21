#!/usr/bin/python

class FilterModule(object):
    def filters(self):
        return {
            'int_between': self.int_between,
            'extract_minute': self.extract_minute,
            'extract_hour': self.extract_hour,
            'extract_weekday': self.extract_weekday,
            'next_minute': self.next_minute,
            'next_hour': self.next_hour,
            'next_weekday': self.next_weekday,
        }
 
    def int_between(self, source_data, min_value, max_value):
        source_int = int(source_data)
        source_int_or_min = max(source_int, min_value)
        return min(source_int_or_min, max_value)

    def extract_minute(self, unixtime):
        return self.next_minute((int(unixtime) / 60), 0)
        
    def extract_hour(self, unixtime):
        return self.next_hour((int(unixtime) / 60 / 60), 0)

    def extract_weekday(self, unixtime):
        return self.next_weekday((int(unixtime) / 60 / 60 / 24 + 4), 0)

    def next_minute(self, current_minute, add=1):
        return int((current_minute + add) % 60)

    def next_hour(self, current_hour, add=1):
        return int((current_hour + add) % 24)

    def next_weekday(self, current_weekday, add=1):
        return int((current_weekday + add) % 7 + 1)
