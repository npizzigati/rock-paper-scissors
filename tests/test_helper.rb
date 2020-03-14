module IoTestHelpers
  # usage example:
  #
  # require_relative '../tests/test_helper.rb'
  # include IoTestHelpers
  # ...
  # def ...
  # actual = simulate_stdin(comma_sep_user_input) { func(args) }
  #
  # where user_input is an array of each instance of user input
  # which will act as if it's separated by carriage returns and
  # func is the function to be tested with its respective
  # args
  def simulate_stdin(*inputs, &block)
    io = StringIO.new
    inputs.flatten.each { |str| io.puts(str) }
    io.rewind
    actual_stdin, $stdin = $stdin, io
    yield
  ensure
    $stdin = actual_stdin
  end
end
