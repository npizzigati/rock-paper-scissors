require 'io/wait'
require 'io/console'

# If curses not installed, fall back on CLI view
begin
  require 'curses'
  # start_game = lambda { RPSGame.new(CursesView.new).play_match }
  start_game = lambda { RPSGame.new(CLIView.new).play_match }
rescue
  start_game = lambda { RPSGame.new(CLIView.new).play_match }
end

SENTIENTS = [{ name: 'VIKI-I', ai: :mirror_loss },
             { name: 'Skynet', ai: :mirror_win },
             { name: 'Hal', ai: :repeat }]

MESSAGES = { opponent:  "Your opponent will be %s. Its " \
                        "moves are not entirely random. Try to " \
                        "figure out the pattern.\n\n",
             any_key:   'Press any key to continue.',
             your_move: 'Your move: (r)ock, (p)aper, (s)cissors, ' \
                        '(l)izard, (S)pock',
             play_again:'Play again (y/n)?',
             your_name: 'Your name? (word characters only): ' }

module Prettier
  def prettier_print(options)
    options = options.map { |option| option != ' ' ? option : 'space' }
    case options.size
    when 1
      options[0]
    when 2
      "#{options[0]} or #{options[1]}"
    when (3...)
      options[0..-2].join(', ') + ' or ' + options[-1]
    end
  end
end

class View
  def retrieve_user_move(move_options)
    choice = input_char(MESSAGES[:your_move],
                   %w(r p s l S))
    move_options[%w(r p s l S).index(choice)]
  end

  def play_again
    response = input_char(MESSAGES[:play_again], %w(y n))
    response == 'y' ? true : false
  end

end

class CLIView < View
  include Prettier

  def input_char(prompt, options=nil)
    puts prompt
    loop do
      entered = STDIN.getch
      quit if entered == "\u0003" # exit program on Ctrl-c
      return entered unless options
      if options.include? entered
        return entered
      else
        puts "Please enter #{prettier_print(options)}"
      end
    end
  end

  def retrieve_user_name
    name = ""
    loop do
      print MESSAGES[:your_name]
      name = gets.chomp
      break unless name.match?(/(\s)|(\W)/)

      puts "\n" + 'Name may not include special characters or spaces.'
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

  def display_round_details(player1, player2, name_winner,
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

  def display_move_history(round_num, player1, player2, name_winner)
    puts "\n"
    review_history = input_char('Press space to continue, h to review' \
                                ' move history or q to quit', [' ', 'h', 'q'])
    return if review_history == ' '
    quit if review_history == 'q'
    clear_screen
    puts "Move history (#{player1.name} vs. #{player2.name}):\n"
    1.upto(round_num) do |idx| 
      puts "Round #{idx}: #{player1.move_history[idx][:move]} " \
           "vs. #{player2.move_history[idx][:move]}\n"
    end
    puts "\n"
    input_char MESSAGES[:any_key]
  end

  def display_computer_name(name)
    puts format(MESSAGES[:opponent], name)
    input_char MESSAGES[:any_key]
  end

  def display_welcome
    clear_screen
    puts 'Welcome to Rock Paper Scissors' + "\n\n"
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

class CursesView < View
  include Prettier

  BOLD = Curses::A_BOLD
  UNDERLINE = Curses::A_UNDERLINE

  attr_accessor :left_top_win, :left_bottom_win, :right_win,
                :right_win, :left_box, :right_box

  def initialize
    Curses.init_screen
    Curses.cbreak
    Curses.noecho
    Curses.curs_set 0 # Invisible cursor
    create_border_boxes
    create_inner_windows
    add_box_headings
    batch_refresh Curses, left_box, right_box
  end

  def add_box_headings
    heading1 = 'Stats and history'
    left_box.setpos 0, (left_box.maxx / 2) - (heading1.size / 2)
    left_box.addstr heading1

    heading2 = 'Rock, Paper, Scissors, Spock, Lizard'
    right_box.setpos 0, 5
    right_box.addstr heading2
  end

  def create_border_boxes
    y_size = Curses.stdscr.maxy
    @wide_x = (Curses.stdscr.maxx * 0.22).round
    narrow_x = Curses.stdscr.maxx - @wide_x - 2
    self.left_box = Curses::Window.new(y_size,
                                       @wide_x,
                                       0,
                                       0)
    apply_attribute(left_box, Curses::A_ALTCHARSET) do
      left_box.box 120, 113
    end

    self.right_box = Curses::Window.new(y_size,
                                        narrow_x,
                                        0,
                                        @wide_x + 1)
    apply_attribute(right_box, Curses::A_ALTCHARSET) do
      right_box.box 120, 113
    end
  end

  def create_inner_windows
    y_size = Curses.stdscr.maxy
    horiz_split = ((left_box.maxy - 4) * 0.20).round
    self.left_top_win = left_box.subwin(horiz_split - 1,
                                        left_box.maxx - 4,
                                        2,
                                        2)

    self.left_bottom_win = left_box.subwin(y_size - horiz_split - 4,
                                           left_box.maxx - 4,
                                           horiz_split + 1,
                                           2)

    self.right_win = right_box.subwin(right_box.maxy - 4,
                                      right_box.maxx - 4,
                                      2,
                                      @wide_x + 3)
  end

  def batch_refresh(*windows)
    windows.each do |window|
      window.refresh
    end
  end

  def apply_attribute(window, attribute, &block)
    window.attron attribute
    yield
    window.attroff attribute
  end

  def print_format(window, attribute, string)
    marker = '^'
    formatted_chars = []
    idx = 0
    chars = string.chars
    while idx < string.size
      if string[idx] != marker
        window.addch chars[idx]
        idx += 1
      else
        idx += 1
        while string[idx] != marker and idx < string.size
          formatted_chars << string[idx]
          idx += 1
        end
        apply_attribute(window, attribute) do
          window.addstr formatted_chars.join
        end
        formatted_chars = []
        idx += 1
      end
    end
  end
  
  def input_char(prompt, options=nil)
    wrong_answer_count = 0
    
    right_win.addstr prompt
    right_win.addstr "\n\n"
    batch_refresh right_win, right_box
    loop do
      entered = right_win.getch
      return entered unless options
      return entered if options.include? entered
      if wrong_answer_count < 1
        apply_attribute(right_win, BOLD) do
          right_win.addstr "Please enter " \
                           "#{prettier_print(options)}\n"
        end
        batch_refresh right_win, right_box
        wrong_answer_count += 1
      end
    end
  end

  def backspace(start_position, entry_position)
    return if entry_position == start_position
    y, x = *entry_position
    right_win.setpos y, x - 1
    right_win.delch
  end

  def hide_error_message(entry_position, error_position)
    right_win.setpos(*error_position)
    right_win.deleteln if right_win.inch
    right_win.setpos(*entry_position)
    batch_refresh right_win, right_box
  end


  def display_error_message(entry_position, error_position, message)
    right_win.setpos(*error_position)
    apply_attribute(right_win, BOLD) { right_win.addstr message }
    right_win.setpos(*entry_position)
  end

  def display_computer_name(name)
    right_win.addstr format(MESSAGES[:opponent], name)
  end

  def retrieve_user_name
    Curses.raw
    name = ""
    error_position = [right_win.cury + 2, right_win.curx]
    error_message = "Name may not include special characters or spaces"
    char_limit_message = "Name may be a maximum of 20 characters"
    right_win.addstr MESSAGES[:your_name]
    start_position = [right_win.cury, right_win.curx]
    loop do
      char_input = right_win.getch
      entry_position = [right_win.cury, right_win.curx]
      # Ignore function keys
      if char_input.size > 1 and !([127, 10, 3].include? char_input)
        clear_stdin
        next
      end
      case char_input
      when 127 # backspace
        hide_error_message(entry_position, error_position)
        backspace(start_position, entry_position)
        name = name[0..-2]
      when 10 # enter
        break
      when 3 # ctrl-c 
        Curses.close_screen
        exit
      when /(\s)|(\W)/
        display_error_message(entry_position, error_position, error_message)
      else
        hide_error_message(entry_position, error_position)
        right_win.addch char_input
        name << char_input
      end
      if name.size > 20
        display_error_message(entry_position, error_position, char_limit_message)
        right_win.delch
        name = name[0..-2]
      end
    batch_refresh right_win, right_box
    end
    Curses.cbreak
    right_win.clear
    batch_refresh right_win, right_box
    name[0].upcase + name[1..-1]
  end

  def clear_stdin
    $stdin.getc while $stdin.ready?
  end

  def display_match_status(round_num, player1, player2)
    left_top_win.clear
    batch_refresh left_top_win, left_box
    apply_attribute(left_top_win, BOLD) do
      left_top_win.addstr "Round #{round_num}\n\n"
    end
    apply_attribute(left_top_win, UNDERLINE) do
      left_top_win.addstr "Current score\n"
    end
    left_top_win.addstr "#{player1.name}: #{player1.score}\n"
    left_top_win.addstr "#{player2.name}: #{player2.score}\n"
    batch_refresh left_top_win, left_box
  end

  def display_round_details(player1, player2, name_winner,
                            round_num, gore)
    right_win.clear
    batch_refresh right_win, right_box

    if player1.move == player2.move
      print_format(right_win, BOLD,
                      "#{player1.name} and #{player2.name} " \
                      "both played #{player1.move}. " \
                      "^Tie!^\n\n")
    else
      print_format(right_win, BOLD,
                      "#{player1.name} played ^#{player1.move}^. " \
                      "#{player2.name} played ^#{player2.move}^. " \
                      "#{gore.capitalize}. " \
                      "#{name_winner} wins!\n\n")
    end
     
    display_match_status(round_num, player1, player2)
    batch_refresh right_win, right_box
  end

  def space_to_continue(player1, player2)
    if player1.score < 10 and player2.score < 10
      continue_or_quit = input_char("Press space to continue on to next round or q to quit.", [" ", "q"])
      if continue_or_quit == "q"
        quit
      end
      right_win.clear
      batch_refresh right_win, right_box
    end
  end

  def display_match_results(player1, player2, name_winner)
    right_win.addstr "Final match results:\n"
    right_win.addstr "#{player1.name} won #{player1.score} rounds\n"
    right_win.addstr "#{player2.name} won #{player2.score} rounds\n"
    right_win.addstr "#{name_winner} has won the match!\n\n"
    batch_refresh right_win, right_box
  end

  def display_move_history(round_num, player1, player2, name_winner)
    if round_num == 1
      apply_attribute(left_bottom_win, UNDERLINE) do
        left_bottom_win.addstr "Move history (P1 vs. P2)\n" 
      end
    end
    space = " " * (round_num < 10 ? 2 : 1)
    if name_winner == player1.name
      print_format(left_bottom_win, BOLD, "R#{round_num}:#{space}" \
                   "^#{player1.move}^ vs. #{player2.move}\n")
    elsif name_winner == player2.name
      print_format(left_bottom_win, BOLD, "R#{round_num}:#{space}" \
                   "#{player1.move} vs. ^#{player2.move}^\n")
    else
      left_bottom_win.addstr "R#{round_num}:#{space}" \
                             "#{player1.move} vs. #{player2.move}\n"
    end
    batch_refresh left_bottom_win, left_box
    space_to_continue(player1, player2)
  end

  def display_welcome
    right_win.addstr "Welcome to Rock Paper Scissors.\n\n" \
                     "First player to win 10 rounds wins the match.\n\n"
    input_char MESSAGES[:any_key]
    right_win.clear
    batch_refresh right_win, right_box
  end

  def display_goodbye
    input_char("Thanks for playing! Press any key to exit.")
  end

  def clear_all
    right_win.clear
    left_top_win.clear
    left_bottom_win.clear
    batch_refresh right_win, right_box, left_top_win,
                  left_bottom_win, left_box
  end

  def quit
    display_goodbye
    Curses.close_screen
    exit
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
  attr_accessor :view, :score, :move_history, :move, :name

  def initialize(view)
    self.view = view
    self.score = 0
    self.move = ""
    self.name = ""
    self.move_history = {}
  end

  def update_move_history(round_num)
    self.move_history[round_num] = {move: move, won: false}
  end

  def to_s
    name
  end
end

class Human < Player
  def initialize(view)
    super(view)
    self.name = view.retrieve_user_name
  end

  def choose_move(move_options, round_num)
    self.move = @view.retrieve_user_move(move_options)
    update_move_history(round_num)
  end
end

class Computer < Player
  attr_accessor :ai, :human_move_history

  def initialize(view, human_move_history)
    super(view)
    self.name, self.ai = retrieve_sentient_details
    self.human_move_history = human_move_history
    view.display_computer_name(name)
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
    case ai
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
    if previous_move[:won]
      self.move = previous_move[:move]
    else
      self.move = move_options.sample
    end
  end

  def ai_mirror_win(move_options, round_num)
    previous_human_turn = human_move_history[round_num - 1]
    if previous_human_turn[:won]
      self.move = previous_human_turn[:move]
    else
      self.move = move_options.sample
    end
  end

  def ai_mirror_loss(move_options, round_num)
    previous_human_move = human_move_history[round_num - 1]
    if !previous_human_move[:won]
      self.move = previous_human_move[:move]
    else
      self.move = move_options.sample
    end
  end
end

# Orchestration engine
class RPSGame
  attr_accessor :player1, :player2, :view,
                :round_num, :move_options

  def initialize(view)
    # TODO: add names for human and computer
    # ask human and select randomly for computer
    self.view = view
    view.display_welcome
    self.move_options = [Rock.new, Paper.new, Scissors.new,
                         Lizard.new, Spock.new]
    self.player1 = Human.new(view)
    self.player2 = Computer.new(view, player1.move_history)
    self.round_num = 1
  end

  def play_match
    loop do
      while player1.score < 10 && player2.score < 10
        view.display_match_status(round_num, player1, player2)
        play_round
      end
      if player1.score > player2.score
        name_winner = player1.name
      else
        name_winner = player2.name
      end
      view.display_match_results(player1, player2, name_winner)
      break unless view.play_again
      reset_match_values
      view.clear_all
    end

    view.quit
  end

  def play_round
    player1.choose_move(move_options, round_num)
    player2.choose_move(move_options, round_num)
    if player1.move > player2.move
      winner = player1
      loser = player2
      player1.move_history[round_num][:won] = true
    elsif player2.move > player1.move
      winner = player2
      loser = player1
      player2.move_history[round_num][:won] = true
    end

    if winner
      winner.score += 1
      gore = retrieve_gore(winner.move.to_s,
                           loser.move.to_s)
      name_winner = winner.name
    else
      gore = nil
      name_winner = nil
    end

    view.display_round_details(player1, player2, name_winner,
                               round_num, gore)
    view.display_move_history(round_num, player1, player2,
                             name_winner)
    self.round_num += 1
  end

  def reset_match_values
    self.player1.score = 0
    self.player2.score = 0
    self.round_num = 1
  end

  def retrieve_gore(winning_move, losing_move)
    gore = ["scissors cuts paper", "paper covers rock",
               "rock crushes lizard", "lizard poisons Spock",
               "Spock smashes scissors",
               "scissors decapitates lizard",
               "lizard eats paper", "paper disproves Spock",
               "Spock vaporizes rock", "rock crushes scissors"]
    gore.filter do |e|
      words = e.split
      words[0] == winning_move && words[2] == losing_move
    end[0]
  end

  def quit
  end
end

if __FILE__ == $PROGRAM_NAME

  # Exit gracefully if interrupted
  def onsig(sig)
    Curses.close_screen
    exit sig
  end

  for i in %w[HUP INT QUIT TERM]
    if trap(i, "SIG_IGN") != 0 then  # 0 for SIG_IGN
      trap(i) { |sig| onsig(sig) }
    end
  end

  start_game.call
end
