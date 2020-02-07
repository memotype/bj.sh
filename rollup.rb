#!/usr/bin/ruby -w

require 'securerandom'


# Regexes to save and replace literals (strings, escaped semicolons, etc)
lits_re = [
  /(?<!\\)"(?:[^"\\]|\\.)*"/,
  /(?<!\\)'[^']*'/,
  /\\;/
]

# List of keywords that shouldn't have semicolons after them
ns_kws = [
  'if',
  'then',
  'elif',
  'else',
  'while',
  'until',
  'do',
  'in'
]

# Regexes to further transform the script, and their replacements
trans_re = [
  [/: ENDBJ(?:.|\n)*/,                ''],
  [/#.*\n/,                           ''],
  [/: :.*\n/,                         ''],
  [/\\\n/,                            ''],
  [/\n+[[:blank:]]*\n*/,              ';'],
  [/[[:blank:]]*;[[:blank:]]*/,       ';'],
  [/[[:blank:]]+/,                    ' '],
  [/ {;/,                             '{ '],
  [/ \(;/,                            '('],
  [/ ?&& ?/,                          '&&'],
  [/;case ([^ ]*) in; *([^\)]*\)) */, ';case \1 in \2'],
  [/ ?;;;* ?/,                        ';;'],
  [/(;;[^;\(]*\)) *;? */,             '\1'],
  [/ *\|\| */,                        '||'],
  [/ *</,                             '<'],

  [/^;/,                              ''],
  [/;$/,                              ''],
]

ns_kws.each { |kw|
  #           [/;if;/,      ';if ']  etc...
  trans_re << [/;(#{kw});/, ';\1 ']
}

if infile = ARGV.shift
  f = File.open infile
  script = f.read
else
  script = STDIN.read
end

if outfile = ARGV.shift
  output = File.open outfile, 'w'
else
  output = STDOUT
end

# Array of replaced literals. We use an array so we can be sure to replace
# them back in the right order, in case there are 'nested' literals.
lits = []

lits_re.each { |re|
  script.gsub!(re) { |str|
    repl = SecureRandom.hex(16)
    lits.unshift [repl, str]
    next repl
  }
}

trans_re.each { |re,repl|
  script.gsub! re, repl
}

lits.each { |repl, str|
  script.gsub! repl, str
}

output.puts ("# (C) Isaac Freeman (memotype@gmail.com). " \
  + "See https://github.com/memotype/bj.sh")
output.puts script
