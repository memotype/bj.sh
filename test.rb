#!/usr/bin/env ruby

require 'open3'
require 'optparse'
require 'tempfile'
require 'yaml'

NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
QUERY_DRIVER = <<~'BASH'
  . "$1" || exit 126
  shift
  [[ $- != *u* ]] || trap '[[ $- == *u* ]] || exit 125' EXIT
  bj "$@"
BASH

# A large fixture cannot cross exec's argument-size limit, so Bash must turn
# this one file into a function argument after the process starts.
FILE_ARGUMENT_DRIVER = <<~'BASH'
  . "$1" || exit 126
  json_file=$2
  shift 2
  [[ $- != *u* ]] || trap '[[ $- == *u* ]] || exit 125' EXIT
  bj "$(<"$json_file")" "$@"
BASH

class CatalogError < StandardError; end

class Catalog
  attr_reader :report, :tests

  def initialize(path, include_timing: false)
    @path = File.expand_path(path)
    document = YAML.safe_load(File.read(@path), aliases: false)
    validate_document(document)
    @report = document.fetch('report')
    @fixtures = document.fetch('fixtures', {})
    all_tests = document.fetch('tests')
    validate_tests(all_tests)
    @tests = all_tests.reject { |test| timing?(test) && !include_timing }
    @skipped = all_tests.length - @tests.length
  rescue Errno::ENOENT, Psych::SyntaxError => error
    raise CatalogError, error.message
  end

  attr_reader :skipped

  def input_for(test)
    input = test.fetch('input')
    if input.key?('json')
      [input.fetch('transport', 'argument'), input.fetch('json')]
    elsif input.key?('fixture')
      fixture = input.fetch('fixture')
      raise CatalogError, "#{test['name']}: unknown fixture #{fixture.inspect}" \
        unless @fixtures.key?(fixture)
      [input.fetch('transport', 'argument'), @fixtures.fetch(fixture)]
    else
      path = File.expand_path(input.fetch('file'), File.dirname(@path))
      ["file-#{input.fetch('transport', 'argument')}", path]
    end
  end

  private

  def validate_document(document)
    raise CatalogError, 'catalog must contain a YAML mapping' unless document.is_a?(Hash)
    raise CatalogError, 'unsupported catalog version' unless document['version'] == 1
    raise CatalogError, 'report must contain success and failure strings' unless
      document['report'].is_a?(Hash) &&
        %w[success failure].all? { |key| document['report'][key].is_a?(String) }
    raise CatalogError, 'fixtures must be a mapping' unless
      document.fetch('fixtures', {}).is_a?(Hash)
    raise CatalogError, 'fixture values must be strings' unless
      document.fetch('fixtures', {}).values.all? { |value| value.is_a?(String) }
    raise CatalogError, 'tests must be an array' unless document['tests'].is_a?(Array)
  end

  def validate_tests(tests)
    names = {}
    tests.each_with_index do |test, index|
      raise CatalogError, "test #{index + 1} must be a mapping" unless test.is_a?(Hash)
      name = test['name']
      raise CatalogError, "test #{index + 1} has an invalid name" unless
        name.is_a?(String) && NAME_PATTERN.match?(name)
      raise CatalogError, "duplicate test name: #{name}" if names[name]
      names[name] = true

      raise CatalogError, "#{name}: description must be a string" unless
        test['description'].is_a?(String)
      raise CatalogError, "#{name}: query must be an array of strings" unless
        test['query'].is_a?(Array) && test['query'].all? { |term| term.is_a?(String) }
      validate_input(name, test['input'])
      validate_expected(name, test)
      validate_shell(name, test.fetch('shell', {}))
      raise CatalogError, "#{name}: tags must be an array of strings" unless
        test.fetch('tags', []).is_a?(Array) &&
          test.fetch('tags', []).all? { |tag| tag.is_a?(String) }
    end
  end

  def validate_input(name, input)
    raise CatalogError, "#{name}: input must be a mapping" unless input.is_a?(Hash)
    sources = %w[json fixture file].select { |key| input.key?(key) }
    raise CatalogError, "#{name}: input needs exactly one source" unless sources.length == 1
    source = sources.first
    raise CatalogError, "#{name}: input #{source} must be a string" unless
      input[source].is_a?(String)
    if source == 'fixture' && !@fixtures.key?(input[source])
      raise CatalogError, "#{name}: unknown fixture #{input[source].inspect}"
    end
    transport = input.fetch('transport', 'argument')
    raise CatalogError, "#{name}: transport must be argument or stdin" unless
      %w[argument stdin].include?(transport)
    if input.key?('trailing-newline') && transport != 'stdin'
      raise CatalogError, "#{name}: trailing-newline requires stdin transport"
    end
    if input.key?('trailing-newline') && ![true, false].include?(input['trailing-newline'])
      raise CatalogError, "#{name}: trailing-newline must be true or false"
    end
  end

  def validate_expected(name, test)
    expected = test['expected']
    raise CatalogError, "#{name}: expected must be a mapping" unless expected.is_a?(Hash)
    raise CatalogError, "#{name}: expected status must be an integer" unless
      expected['status'].is_a?(Integer)
    operation = test.fetch('operation', 'query')
    raise CatalogError, "#{name}: unsupported operation #{operation.inspect}" unless
      %w[query iterate].include?(operation)
    output = expected['output']
    valid_output = operation == 'iterate' ?
      output.is_a?(Array) && output.all? { |item| item.is_a?(String) } :
      output.is_a?(String)
    raise CatalogError, "#{name}: expected output has the wrong type" unless valid_output
  end

  def validate_shell(name, shell)
    raise CatalogError, "#{name}: shell must be a mapping" unless shell.is_a?(Hash)
    return unless shell.key?('nounset') && ![true, false].include?(shell['nounset'])
    raise CatalogError, "#{name}: shell nounset must be true or false"
  end

  def timing?(test)
    test.fetch('tags', []).include?('timing')
  end
end

class Runner
  def initialize(catalog, source, drivers)
    @catalog = catalog
    @source = File.expand_path(source)
    @drivers = drivers
  end

  def run
    passed = 0
    failed = 0

    puts "Testing #{@source}"
    @catalog.tests.each do |test|
      result = run_test(test)
      success = result[:output] == test.dig('expected', 'output') &&
        result[:status] == test.dig('expected', 'status')
      success ? passed += 1 : failed += 1
      report(test, result, success)
    rescue StandardError => error
      failed += 1
      report_error(test, error)
    end

    total = passed + failed
    puts "Summary: #{total} run, #{passed} passed, #{failed} failed, " \
      + "#{@catalog.skipped} skipped"
    failed.zero? ? 0 : 1
  end

  private

  def run_test(test)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    output, status, stderr = if test.fetch('operation', 'query') == 'iterate'
      run_iteration(test)
    else
      run_query(test)
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    {output: output, status: status, stderr: stderr, elapsed: elapsed}
  end

  def run_iteration(test)
    output = []
    stderr = []
    index = 0
    expected_count = test.dig('expected', 'output').length
    loop do
      actual, status, error = invoke(test, test.fetch('query') + [index.to_s])
      stderr << error unless error.empty?
      return [output, status, stderr.join] unless status.zero?
      output << actual
      index += 1
      return [output, status, stderr.join] if index > expected_count
    end
  end

  def run_query(test)
    output, status, stderr = invoke(test, test.fetch('query'))
    [output, status, stderr]
  end

  def invoke(test, query)
    transport, input = @catalog.input_for(test)
    command = ['bash']
    command << '-u' if test.dig('shell', 'nounset')
    stdin_data = ''
    stdin_file = nil

    case transport
    when 'argument'
      command.concat([@drivers.fetch(:query), @source, input, *query])
    when 'stdin'
      command.concat([@drivers.fetch(:query), @source, '-', *query])
      stdin_data = input + (test.dig('input', 'trailing-newline') ? "\n" : '')
    when 'file-stdin'
      ensure_readable(input)
      command.concat([@drivers.fetch(:query), @source, '-', *query])
      stdin_file = input
    when 'file-argument'
      ensure_readable(input)
      command.concat([@drivers.fetch(:file_argument), @source, input, *query])
    else
      raise "unknown input transport: #{transport}"
    end

    stdout, stderr, process = capture(
      command, stdin_data: stdin_data, stdin_file: stdin_file
    )
    stdout.force_encoding(Encoding::UTF_8)
    stderr.force_encoding(Encoding::UTF_8)
    status = process.exitstatus || 128 + process.termsig
    [stdout, status, stderr]
  end

  def capture(command, stdin_data:, stdin_file:)
    Open3.popen3(*command) do |stdin, stdout, stderr, process|
      stdout_reader = Thread.new { stdout.read }
      stderr_reader = Thread.new { stderr.read }

      begin
        if stdin_file
          File.open(stdin_file, 'rb') { |file| IO.copy_stream(file, stdin) }
        else
          stdin.write(stdin_data)
        end
      rescue Errno::EPIPE
        # The implementation exited without consuming all of its input.
      ensure
        stdin.close
      end

      [stdout_reader.value, stderr_reader.value, process.value]
    end
  end

  def ensure_readable(path)
    raise "input file is not readable: #{path}" unless File.readable?(path)
  end

  def report(test, result, success)
    key = success ? 'success' : 'failure'
    message = format(
      @catalog.report.fetch(key),
      name: test.fetch('name'), description: test.fetch('description')
    )
    expected = test.fetch('expected')
    line = "#{message} | status actual=#{result[:status]} " \
      + "expected=#{expected.fetch('status')} | output actual=" \
      + "#{result[:output].inspect} expected=#{expected.fetch('output').inspect}"
    line += format(' | %.3fs', result[:elapsed]) if test.fetch('tags', []).include?('timing')
    puts line
    puts "  stderr: #{result[:stderr].inspect}" unless result[:stderr].empty?
  end

  def report_error(test, error)
    name = test.is_a?(Hash) ? test.fetch('name', 'unknown-test') : 'unknown-test'
    description = test.is_a?(Hash) ? test.fetch('description', error.message) : error.message
    message = format(@catalog.report.fetch('failure'), name: name, description: description)
    puts "#{message} | runner error: #{error.message}"
  end
end

options = {catalog: File.join(__dir__, 'tests.yml'), source: File.join(__dir__, 'bj.sh')}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: test.rb [-s PATH] [-f PATH] [-t]'
  opts.on('-s', '--source PATH', 'implementation to source') { |path| options[:source] = path }
  opts.on('-f', '--file PATH', 'YAML test catalog') { |path| options[:catalog] = path }
  opts.on('-t', '--timing', 'include optional timing tests') { options[:timing] = true }
end
parser.parse!

begin
  catalog = Catalog.new(options[:catalog], include_timing: options[:timing])
  Tempfile.create(['bj-query-driver', '.sh']) do |query_driver|
    query_driver.write(QUERY_DRIVER)
    query_driver.flush
    Tempfile.create(['bj-file-argument-driver', '.sh']) do |file_argument_driver|
      file_argument_driver.write(FILE_ARGUMENT_DRIVER)
      file_argument_driver.flush
      drivers = {query: query_driver.path, file_argument: file_argument_driver.path}
      exit Runner.new(catalog, options[:source], drivers).run
    end
  end
rescue CatalogError => error
  warn "Test catalog error: #{error.message}"
  exit 1
end
