require 'io/wait'
require 'io/console'

# If curses not installed, fall back on CLI view
begin
  require 'curses'
  BOLD = Curses::A_BOLD
  UNDERLINE = Curses::A_UNDERLINE
  CURSES = true
  start_game = -> { RPSGame.new(CursesView.new).play_match }
rescue LoadError
  start_game = -> { RPSGame.new(CLIView.new).play_match }
end

SENTIENTS = [{ name: 'VIKI-I', ai: :mirror_loss },
             { name: 'Skynet', ai: :mirror_win },
             { name: 'Hal', ai: :repeat }]

MSG = { opponent: 'Your opponent will be %<name>s. Its ' \
        'moves are not entirely random. Try to ' \
        'figure out the pattern.',
        any_key: 'Press any key to continue.',
        your_move: 'Your move: (r)ock, (p)aper, (s)cissors, ' \
        '(l)izard, (S)pock',
        play_again: 'Play again (y/n)?',
        your_name: 'Your name? (word characters only): ',
        welcome: 'Welcome to Rock, Paper, Scissors, ' \
        'Lizard, Spock',
        rules: "Rules: Scissors cuts paper. Paper covers rock. " \
        "Rock crushes lizard.\nLizard poisons Spock. Spock smashes " \
        "scissors. Scissors decapitates lizard.\nLizard eats paper. " \
        "Paper disproves Spock. Spock vaporizes rock. \nRock crushes " \
        "scissors.\n\nFirst player to win 10 rounds wins the match.",
        name_char_error: 'Name may not include special ' \
        'characters or spaces.',
        name_limit_error: 'Name may be a maximum of 20 ' \
        'characters.' }

module Prettier
  def prettier_print(options)
    options = options.map { |option| option == ' ' ? 'space' : option }
    case options.size
    when 1
      options[0]
    when 2
      "#{options[0]} or #{options[1]}"
    when 3..10
      options[0..-2].join(', ') + ' or ' + options[-1]
    end
  end
end

class View
  def retrieve_user_move(move_options)
    choice = input_char(MSG[:your_move], %w(r p s l S))
    move_options[%w(r p s l S).index(choice)]
  end

  def play_again?
    response = input_char(MSG[:play_again], %w(y n))
    response == 'y'
  end
end

class CLIView < View
  include Prettier

  def input_char(prompt, options=nil)
    puts prompt
    loop do
      entered = STDIN.getch
      quit if entered == "\u0003" # exit program on Ctrl-c
      return entered if !options || options.include?(entered)

      puts "Please enter #{prettier_print(options)}"
    end
  end

  def name_valid?(name)
    name !~ (/(\s)|(\W)/) && name.size <= 20
  end

  def retrieve_user_name
    name = ""
    loop do
      print MSG[:your_name]
      name = gets.chomp
      break if name_valid?(name)

      puts "\n • " + MSG[:name_char_error]
      puts " • " + MSG[:name_limit_error] + "\n\n"
    end

    name[0].upcase + name[1..-1]
  end

  def print_in_box(string)
    puts '*' * (string.size + 4)
    puts '* ' + string + ' *'
    puts '*' * (string.size + 4)
  end

  def display_match_status(round_num, player1, player2)
    clear_screen
    print_in_box("Round #{round_num}")
    puts "Current score:\n"
    puts "#{player1.name}: #{player1.score}\n"
    puts "#{player2.name}: #{player2.score}\n\n"
  end

  def display_round_info(player1, player2, name_winner,
                         round_num, gore)
    display_match_status(round_num, player1, player2)

    if !name_winner
      puts "#{player1.name} and #{player2.name} both played " \
           "#{player1.move}. Tie!\n"
    else
      puts "#{player1.name} played #{player1.move} and " \
           "#{player2.name} played #{player2.move}.\n" \
           "#{gore.capitalize}. " \
           "#{name_winner} wins!\n"
    end
  end

  def display_match_results(player1, player2, name_winner)
    puts "Final match results:\n"
    puts "#{player1.name} won #{player1.score} rounds\n"
    puts "#{player2.name} won #{player2.score} rounds\n"
    puts "#{name_winner} has won the match!\n\n"
  end

  def display_history?
    puts "\n"
    answer = input_char('Press space to continue or h to review' \
                                ' move history', [' ', 'h'])
    answer == 'h'
  end

  def won_round?(player, round)
    player.move_history[round][:won]
  end

  def list_history(final_round_in_history, player1, player2)
    1.upto(final_round_in_history) do |round|
      puts "Round #{round}: #{player1.move_history[round][:move]}" +
           (won_round?(player1, round) ? "✓" : "") +
           " vs. #{player2.move_history[round][:move]}" +
           (won_round?(player2, round) ? "✓" : "") + "\n"
    end
  end

  def display_move_history(final_round_in_history, player1,
                           player2, _name_winner)
    return unless display_history?

    clear_screen
    puts "Move history (#{player1.name} vs. #{player2.name}):\n\n"
    puts "(Check mark beside move indicates winning move.)"
    list_history(final_round_in_history, player1, player2)
    input_char MSG[:any_key]
    clear_screen
  end

  def display_computer_name(name)
    puts "\n" + format(MSG[:opponent], { name: name }) + "\n\n"
    input_char MSG[:any_key]
  end

  def display_welcome
    clear_screen
    puts MSG[:welcome] + "\n\n" + MSG[:rules] + "\n\n"
  end

  def display_goodbye
    clear_screen
    puts 'Thanks for playing!'
  end

  def quit
    display_goodbye
    exit
  end

  def clear_screen
    system('clear') || system('cls')
    puts "\n"
  end

  def clear_all
    clear_screen
  end
end

class CursesNameInput
  def initialize(view)
    @view = view
    @right_win = @view.right_win
    @right_box = @view.right_box
    @name = ""
    @error_position = [@right_win.cury + 2, @right_win.curx]
    Curses.raw
    @right_win.addstr MSG[:your_name]
    @start_position = [@right_win.cury, @right_win.curx]
  end

  def retrieve_user_name
    loop do
      char = retrieve_valid_keystroke
      process_special_keystrokes(char)
      next if char == 127 # backspace
      break if char == 10 && !@name.empty? # enter at word end

      add_char(char) if char != 10 # don't add enter to actual name
      enforce_size_limit
    end
    cleanup
    @name[0].upcase + @name[1..-1]
  end

  private

  def add_char(char)
    hide_error
    @right_win.addch char
    @view.batch_refresh @right_win, @right_box
    @name << char
  end

  def enforce_size_limit
    return unless @name.size > 20

    display_error(MSG[:name_limit_error])
    @right_win.delch
    @name = @name[0..-2]
  end

  def process_special_keystrokes(char)
    case char
    when 127 # backspace
      backspace
    when 3 # ctrl-c
      @view.quit
    end
  end

  def non_word_char?(char)
    char.match?(/(\s)|(\W)/)
  end

  def non_integer?(char)
    char.class != Integer
  end

  def retrieve_single_keystroke
    clear_stdin
    @right_win.getch
  end

  def retrieve_valid_keystroke
    loop do
      @entry_position = [@right_win.cury, @right_win.curx]
      char = retrieve_single_keystroke
      next if control_char?(char)

      return char unless non_integer?(char) && non_word_char?(char)

      display_error(MSG[:name_char_error])
    end
  end

  def control_char?(char)
    char.size > 1 && !([127, 10, 3].include?(char))
  end

  def backspace
    return if @entry_position == @start_position

    hide_error
    y, x = *@entry_position
    @right_win.setpos y, x - 1
    @right_win.delch
    @view.batch_refresh @right_win, @right_box
    @name = @name[0..-2]
  end

  def hide_error
    @right_win.setpos(*@error_position)
    @right_win.deleteln if @right_win.inch
    @right_win.setpos(*@entry_position)
    @view.batch_refresh @right_win, @right_box
  end

  def display_error(message)
    @right_win.setpos(*@error_position)
    @view.apply_attribute(@right_win, BOLD) { @right_win.addstr message }
    @right_win.setpos(*@entry_position)
    @view.batch_refresh @right_win, @right_box
  end

  def cleanup
    Curses.cbreak
    @right_win.clear
    @view.batch_refresh @right_win, @right_box
  end

  def clear_stdin
    $stdin.getc while $stdin.ready?
  end
end

class CursesView < View
  include Prettier

  attr_reader :right_win, :right_box

  def initialize
    Curses.init_screen
    Curses.cbreak
    Curses.noecho
    Curses.curs_set 0
    create_border_boxes
    create_inner_windows
    add_box_headings
    batch_refresh Curses, @left_box, @right_box
    @bolder = Formatter.new(self, attribute: BOLD)
    @underliner = Formatter.new(self, attribute: UNDERLINE)
  end

  def display_computer_name(name)
    @right_win.addstr "\n" + format(MSG[:opponent],
                                    { name: name }) + "\n\n"
  end

  def display_match_status(round_num, player1, player2)
    @left_top_win.clear
    @bolder.print(@left_top_win, "^Round #{round_num}\n\n^")
    @underliner.print(@left_top_win, "^Current score\n^")
    @left_top_win.addstr "#{player1.name}: #{player1.score}\n" \
                        "#{player2.name}: #{player2.score}\n"
    batch_refresh @left_top_win, @left_box
  end

  def display_round_info(player1, player2, name_winner, round_num, gore)
    @right_win.clear

    if player1.move == player2.move
      print_tie_message(player1, player2)
    else
      print_win_message(player1, player2, name_winner, gore)
    end

    display_match_status(round_num, player1, player2)
    batch_refresh @right_win, @right_box
  end

  def display_match_results(player1, player2, name_winner)
    @right_win.addstr "Final match results:\n"
    @right_win.addstr "#{player1.name} won #{player1.score} rounds\n"
    @right_win.addstr "#{player2.name} won #{player2.score} rounds\n"
    @right_win.addstr "#{name_winner} has won the match!\n\n"
    batch_refresh @right_win, @right_box
  end

  def display_move_history(round_num, player1, player2, name_winner)
    print_history_heading if round_num == 1
    space = " " * (round_num < 10 ? 2 : 1)
    if name_winner == player1.name
      print_history_p1_win(round_num, player1, player2, space)
    elsif name_winner == player2.name
      print_history_p2_win(round_num, player1, player2, space)
    else
      print_history_tie(round_num, player1, player2, space)
    end
    space_to_continue(player1, player2)
  end

  def display_welcome
    @right_win.addstr MSG[:welcome] + "\n\n" +
                      MSG[:rules] + "\n\n"
    input_char MSG[:any_key]
    @right_win.clear
    batch_refresh @right_win, @right_box
  end

  def display_goodbye
    input_char("\nThanks for playing! Press any key to exit.")
  end

  def batch_refresh(*windows)
    windows.each(&:refresh)
  end

  def apply_attribute(window, attribute)
    window.attron attribute
    yield
    window.attroff attribute
  end

  def refresh_all
    windows = [@left_box, @right_box, @left_top_win, @left_bottom_win,
               @right_win]
    batch_refresh(*windows)
  end

  def clear_all
    @right_win.clear
    @left_top_win.clear
    @left_bottom_win.clear
    batch_refresh @right_win, @right_box, @left_top_win,
                  @left_bottom_win, @left_box
  end

  def quit
    display_goodbye
    Curses.close_screen
    exit
  end

  private

  def add_box_headings
    left_heading = 'Stats and history'
    @left_box.setpos 0, (@left_box.maxx / 2) - (left_heading.size / 2)
    @left_box.addstr left_heading

    right_heading = 'Rock, Paper, Scissors, Spock, Lizard'
    @right_box.setpos 0, 5
    @right_box.addstr right_heading
  end

  def create_border_boxes
    @height = Curses.stdscr.maxy
    @left_width = (Curses.stdscr.maxx * 0.22).round
    @right_width = Curses.stdscr.maxx - @left_width - 2

    create_left_box
    create_right_box
  end

  def create_left_box
    @left_box = Curses::Window.new(@height,
                                   @left_width,
                                   0,
                                   0)
    apply_attribute(@left_box, Curses::A_ALTCHARSET) do
      @left_box.box 120, 113
    end
  end

  def create_right_box
    @right_box = Curses::Window.new(@height,
                                    @right_width,
                                    0,
                                    @left_width + 1)
    apply_attribute(@right_box, Curses::A_ALTCHARSET) do
      @right_box.box 120, 113
    end
  end

  def create_left_top_window
    @left_top_win = @left_box.subwin(@horiz_split - 1,
                                     @left_box.maxx - 4,
                                     2,
                                     2)
  end

  def create_left_bottom_window
    @left_bottom_win = @left_box.subwin(@height - @horiz_split - 4,
                                        @left_box.maxx - 4,
                                        @horiz_split + 1,
                                        2)
  end

  def create_right_window
    @right_win = @right_box.subwin(@right_box.maxy - 4,
                                   @right_box.maxx - 4,
                                   2,
                                   @left_width + 3)
  end

  def create_inner_windows
    @height = Curses.stdscr.maxy
    @horiz_split = ((@left_box.maxy - 4) * 0.20).round
    create_left_top_window
    create_left_bottom_window
    create_right_window
  end

  def display_prompt(prompt)
    @right_win.addstr "#{prompt}\n\n"
    batch_refresh @right_win, @right_box
  end

  def input_char(prompt, options=nil)
    display_prompt(prompt)
    error_message_already_displayed = false
    loop do
      entered = @right_win.getch
      return entered if !options || options.include?(entered)

      if !error_message_already_displayed
        @bolder.print(@right_win, "^Please enter #{prettier_print(options)}^\n")
        error_message_already_displayed = true
      end
    end
  end

  def print_win_message(player1, player2, name_winner, gore)
    @bolder.print(@right_win, "#{player1.name} played ^#{player1.move}^. " \
                  "#{player2.name} played ^#{player2.move}^. " \
                  "#{gore.capitalize}. #{name_winner} wins!\n\n")
  end

  def print_tie_message(player1, player2)
    @bolder.print(@right_win, "#{player1.name} and #{player2.name} " \
                  "both played #{player1.move}. ^Tie!^\n\n")
  end

  def space_to_continue(player1, player2)
    return unless player1.score < 10 && player2.score < 10

    continue_or_quit = input_char("Press space to continue to " \
                                  "next round or q to quit.",
                                  [" ", "q"])
    if continue_or_quit == "q"
      quit
    end
    @right_win.clear
    batch_refresh @right_win, @right_box
  end

  def print_history_p1_win(round_num, player1, player2, space)
    @bolder.print(@left_bottom_win, "R#{round_num}:#{space}" \
                "^#{player1.move}^ vs. #{player2.move}\n", false)
  end

  def print_history_p2_win(round_num, player1, player2, space)
    @bolder.print(@left_bottom_win, "R#{round_num}:#{space}" \
                "#{player1.move} vs. ^#{player2.move}^\n", false)
  end

  def print_history_tie(round_num, player1, player2, space)
    @left_bottom_win.addstr "R#{round_num}:#{space}" \
                            "#{player1.move} vs. #{player2.move}\n"
  end

  def print_history_heading
    @underliner.print(@left_bottom_win, "^Move history (P1 vs. P2)^\n",
                      false)
  end
end

class Formatter
  def initialize(view, marker: '^', attribute: BOLD)
    @marker = marker
    @attribute = attribute
    @view = view
  end

  def print(window, string, refresh=true)
    @idx = 0
    while @idx < string.size
      if string[@idx] != @marker
        window.addch string[@idx]
      else
        print_chars_between_markers(window, string)
      end
      @idx += 1
    end
    @view.refresh_all if refresh == true
  end

  def print_chars_between_markers(window, string)
    @idx += 1
    while string[@idx] != @marker && @idx < string.size
      @view.apply_attribute(window, @attribute) do
        window.addch string[@idx]
      end
      @idx += 1
    end
  end
end

class Weapon
  def to_s
    name = self.class.name
    name == 'Spock' ? name : name.downcase
  end
end

class Rock < Weapon
  def >(other)
    %w(scissors lizard).include? other.to_s
  end
end

class Scissors < Weapon
  def >(other)
    %w(paper lizard).include? other.to_s
  end
end

class Paper < Weapon
  def >(other)
    %w(rock Spock).include? other.to_s
  end
end

class Lizard < Weapon
  def >(other)
    %w(Spock paper).include? other.to_s
  end
end

class Spock < Weapon
  def >(other)
    %w(rock scissors).include? other.to_s
  end
end

class Player
  attr_accessor :name, :score, :move, :move_history

  def initialize(view)
    @view = view
    self.move = ""
    self.name = ""
    self.score = 0
    self.move_history = {}
  end

  def to_s
    name
  end

  private

  def update_move_history(round_num)
    move_history[round_num] = { move: move, won: false }
  end
end

class Human < Player
  def initialize(view)
    super(view)
    self.name = if @view.class == CursesView
                  CursesNameInput.new(@view).retrieve_user_name
                else
                  self.name = @view.retrieve_user_name
                end
  end

  def choose_move(move_options, round_num)
    self.move = @view.retrieve_user_move(move_options)
    update_move_history(round_num)
  end
end

class Computer < Player
  def initialize(view, human_move_history)
    super(view)
    self.name, @ai = retrieve_sentient_details
    @human_move_history = human_move_history
    @view.display_computer_name(name)
  end

  def retrieve_sentient_details
    sentient = SENTIENTS.sample
    [sentient[:name], sentient[:ai]]
  end

  def choose_move(move_options, round_num)
    if round_num == 1
      self.move = move_options.sample
    else
      ai_move(move_options, round_num)
    end
    update_move_history(round_num)
  end

  def ai_move(move_options, round_num)
    case @ai
    when :repeat
      ai_repeat(move_options, round_num)
    when :mirror_win
      ai_mirror_win(move_options, round_num)
    when :mirror_loss
      ai_mirror_loss(move_options, round_num)
    end
  end

  def ai_repeat(move_options, round_num)
    previous_move = move_history[round_num - 1]
    self.move = if previous_move[:won]
                  previous_move[:move]
                else
                  move_options.sample
                end
  end

  def ai_mirror_win(move_options, round_num)
    previous_human_turn = @human_move_history[round_num - 1]
    self.move = if previous_human_turn[:won]
                  previous_human_turn[:move]
                else
                  move_options.sample
                end
  end

  def ai_mirror_loss(move_options, round_num)
    previous_human_move = @human_move_history[round_num - 1]
    self.move = if !previous_human_move[:won]
                  previous_human_move[:move]
                else
                  move_options.sample
                end
  end
end

# Orchestration engine
class RPSGame
  def initialize(view)
    @view = view
    @view.display_welcome
    @move_options = [Rock.new, Paper.new, Scissors.new,
                     Lizard.new, Spock.new]
    @player1 = Human.new(@view)
    @player2 = Computer.new(@view, @player1.move_history)
    @round_num = 1
  end

  def play_match
    loop do
      play_rounds
      @view.display_match_results(@player1, @player2, determine_match_winner)
      break unless @view.play_again?

      reset_match
    end
    @view.quit
  end

  private

  def play_rounds
    while @player1.score < 10 && @player2.score < 10
      @view.display_match_status(@round_num, @player1, @player2)
      play_individual_round
    end
  end

  def determine_match_winner
    @player1.score > @player2.score ? @player1.name : @player2.name
  end

  def reset_match
    reset_match_values
    @view.clear_all
  end

  def choose_moves
    @player1.choose_move(@move_options, @round_num)
    @player2.choose_move(@move_options, @round_num)
  end

  def play_individual_round
    choose_moves
    winner, loser = determine_winner_and_loser
    if winner
      winner.score += 1
      winner.move_history[@round_num][:won] = true
      gore = retrieve_gore(winner.move.to_s, loser.move.to_s)
    else
      gore = nil
    end

    winner ? final_round_tasks(winner.name, gore) : final_round_tasks(nil, gore)
  end

  def determine_winner_and_loser
    winner = nil
    loser = nil
    if @player1.move > @player2.move
      winner = @player1
      loser = @player2
    elsif @player2.move > @player1.move
      winner = @player2
      loser = @player1
    end
    [winner, loser]
  end

  def final_round_tasks(name_winner, gore)
    @view.display_round_info(@player1, @player2, name_winner, @round_num, gore)
    @view.display_move_history(@round_num, @player1, @player2, name_winner)
    @round_num += 1
  end

  def reset_match_values
    @player1.score = 0
    @player2.score = 0
    @round_num = 1
  end

  def retrieve_gore(winning_move, losing_move)
    gore = ["scissors cuts paper", "paper covers rock",
            "rock crushes lizard", "lizard poisons Spock",
            "Spock smashes scissors", "scissors decapitates lizard",
            "lizard eats paper", "paper disproves Spock",
            "Spock vaporizes rock", "rock crushes scissors"]
    gore.filter do |e|
      words = e.split
      words[0] == winning_move && words[2] == losing_move
    end[0]
  end
end

if $PROGRAM_NAME == __FILE__

  # Exit Curses gracefully if interrupted
  def onsig(sig)
    Curses.close_screen if CURSES
    exit sig
  end

  %w(HUP INT QUIT TERM).each do |i|
    if trap(i, "SIG_IGN") != 0
      trap(i) { |sig| onsig(sig) }
    end
  end

  start_game.call
end
