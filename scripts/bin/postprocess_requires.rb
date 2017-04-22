#!/usr/bin/env ruby

file_name = ARGV[0]
file_content = IO.read(file_name)
file_content.gsub! /^_require '(.*)'/ do
  puts %Q{Found "_require '#{$1}' directive", replaced with the content of 'src/#{$1}' file}
  IO.read "src/#{$1}"
end
IO.write(file_name, file_content)
